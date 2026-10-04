"""Export durable Lab overlays as a checksummed, base-bound repair bundle."""
import argparse
import hashlib
import json
import sys
import uuid
import zipfile
from datetime import datetime, timezone
from pathlib import Path

FIELDS = {'name': 'name', 'name_hi': 'name_hi', 'aliases': 'alternate_names', 'description': 'description',
          'category': 'classification.category', 'subcategory': 'classification.subcategory',
          'latitude': 'location.latitude', 'longitude': 'location.longitude', 'address': 'location.address',
          'website': 'contact.website', 'phone': 'contact.phone', 'tier': 'tier', 'opening_hours': 'opening_hours', 'media': 'images'}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def value(row, field):
    for key in FIELDS[field].split('.'):
        row = row.get(key) if isinstance(row, dict) else None
    return row


def safe(root, relative):
    target = (root / relative).resolve()
    if not target.is_relative_to(root.resolve()) or '\\' in relative or Path(relative).is_absolute():
        raise ValueError('Unsafe media path')
    return target


def export_patch(pack, factory, output, place_ids=None):
    pack, factory, output = Path(pack).resolve(), Path(factory).resolve(), Path(output).resolve()
    receipt = json.loads((pack / 'lab_sync_receipt.json').read_text(encoding='utf-8'))
    source = Path(receipt.get('source_path') or receipt.get('source') or factory / receipt['source_release']).resolve()
    if not source.is_relative_to((factory / 'releases').resolve()):
        raise ValueError('Source receipt must point to immutable DataFactory releases')
    if digest(pack / 'yatracanvas.db') != digest(source / 'yatracanvas.db'):
        raise ValueError('Lab baseline differs from source database; re-sync before exporting')
    city = json.loads((source / 'city.json').read_text(encoding='utf-8'))
    baseline = {p['id']: p for p in json.loads((source / 'places.json').read_text(encoding='utf-8'))}
    curation = pack / 'curation'
    files, changes = {}, []
    sys.path.insert(0, str(factory))
    from datafactory.utils.hashing import generate_canonical_place_id
    from datafactory.citylab_patch import validate_value
    additions = {a['id']: a for a in (json.loads(p.read_text(encoding='utf-8')) for p in sorted((curation / 'additions').glob('*.json')))}
    combined_additions = {}
    for old_id, addition in additions.items():
        if addition['city_id'] != city['id']:
            raise ValueError('Addition belongs to another city')
        combined_additions[old_id] = {k: addition[k] for k in FIELDS if k in addition and k not in {'opening_hours', 'media'} and addition[k] is not None}
        if addition.get('opening_hours'):
            combined_additions[old_id]['opening_hours'] = {'raw':addition['opening_hours'], 'normalized':addition['opening_hours'], 'verified':False, 'source':addition.get('evidence_source') or 'City Lab manual addition', 'confidence':0.0, 'conflicts':[]}
        if addition.get('primary_image_path'):
            raise ValueError('Import the new place photo through the photo curator so provenance is recorded')
    ignored = []
    # Exclusion/removal of POIs requires dependency review, deliberately rejected.
    exclusions = [p.stem for p in (curation / 'exclusions').glob('*.json')]
    if place_ids and set(exclusions) & set(place_ids):
        raise ValueError('POI exclusions need dependency review; export field repairs separately')
    for path in sorted((curation / 'overrides').glob('*.json')):
        overlay = json.loads(path.read_text(encoding='utf-8'))
        pid = overlay['place_id']
        if place_ids and pid not in place_ids:
            continue
        valid_versions = {source.name, json.loads((source / 'manifest.json').read_text(encoding='utf-8')).get('generated_at')}
        fresh = lambda key: overlay.get('field_versions', {}).get(key, overlay.get('pack_version')) in valid_versions
        if overlay.get('pack_version') not in valid_versions and not any(fresh(k) for k in overlay if k in FIELDS or k == 'primary_image_path'):
            raise ValueError(f'Overlay {pid} predates this baseline. Re-review it or export only current repair IDs.')
        if overlay['city_id'] != city['id'] or pid not in baseline and pid not in additions:
            raise ValueError('Override city or place ID does not match source')
        edits = {field: overlay[field] for field in FIELDS if field in overlay and fresh(field) and field not in {'opening_hours', 'media'}}
        if 'opening_hours' in overlay and fresh('opening_hours'):
            raw = overlay['opening_hours'] or None
            verified = overlay.get('opening_hours_status') == 'VERIFIED'
            edits['opening_hours'] = {'raw': raw, 'normalized': raw,
                'source': overlay.get('field_sources', {}).get('opening_hours') or 'City Lab manual entry',
                'verified': verified if raw else False, 'confidence': 1.0 if verified and raw else 0.0,
                'retrieved_at': overlay.get('updated_at'), 'conflicts': []}
        if 'primary_image_path' in overlay and fresh('primary_image_path'):
            image_path = overlay['primary_image_path']
            if not image_path:
                edits['media'] = None
            else:
                meta_file = curation / 'media' / (pid + '.json')
                if not meta_file.exists():
                    raise ValueError(f'Image has no import provenance: {pid}')
                meta = json.loads(meta_file.read_text(encoding='utf-8'))
                relative = meta['primaryImagePath']
                if relative != image_path:
                    raise ValueError('Media metadata and override paths differ')
                photo = safe(pack, relative)
                from PIL import Image
                with Image.open(photo) as decoded:
                    decoded.verify()
                name = f'media/{pid}.webp'
                files[name] = photo.read_bytes()
                test = meta.get('mediaClass') == 'TEST_ONLY_REAL'
                edits['media'] = {'file': name, 'media_class': 'TEST_ONLY_REAL' if test else 'VERIFIED_REAL',
                    'source': meta.get('source'), 'source_page': meta.get('sourcePage'), 'author': meta.get('author'),
                    'license': meta.get('license'), 'license_url': meta.get('licenseUrl'),
                    'attribution': meta.get('attribution'), 'original_filename': meta.get('originalFilename'),
                    'contributor': overlay.get('author'), 'identity_confirmed': meta.get('identityConfirmed', False),
                    'real_photograph_confirmed': meta.get('realPhotographConfirmed', False)}
        for field, data in edits.items():
            validate_value(field, data)
        if pid in additions:
            combined_additions[pid].update(edits)
            continue
        edits = {k: v for k, v in edits.items() if k == 'media' or value(baseline[pid], k) != v}
        if not edits:
            ignored.append(pid); continue
        changes.append({'place_id': pid, 'operation': 'UPDATE', 'changes': edits,
                        'before': {k: value(baseline[pid], k) for k in edits}, 'author': overlay.get('author')})
    for old_id, edits in combined_additions.items():
        if place_ids and old_id not in place_ids:
            continue
        for field, data in edits.items():
            validate_value(field, data)
        addition = additions[old_id]
        pid = generate_canonical_place_id(city['country'], city['state'], city['name'], edits['name'])
        changes.append({'place_id':pid, 'operation':'ADD', 'changes':edits, 'before':{}, 'author':addition.get('author')})
    if not changes:
        raise ValueError('No field repairs or additions to export')
    files['changes.json'] = json.dumps(changes, ensure_ascii=False, indent=2).encode('utf-8')
    files['README.md'] = b'City Lab repair bundle. Dry-run in DataFactory before apply. Old releases remain immutable.\n'
    manifest = {'patch_schema_version': 1, 'patch_id': 'citylab-' + uuid.uuid4().hex,
        'city_id': city['id'], 'city_name': city['name'], 'state': city['state'], 'country': city['country'],
        'source_pack_version': source.name, 'source_pack_fingerprint': {n: digest(source / n) for n in
            ('places.json', 'city.json', 'media_assurance.json', 'field_provenance.json', 'checksums.json') if (source / n).exists()},
        'created_at': datetime.now(timezone.utc).isoformat(), 'change_count': len(changes),
        'media_count': sum(n.startswith('media/') for n in files), 'excluded_operations_not_exported': exclusions,
        'checksums': {n: hashlib.sha256(content).hexdigest() for n, content in files.items()}}
    if output.exists():
        raise ValueError('Patch already exists, choose another output')
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'x', zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('manifest.json', json.dumps(manifest, ensure_ascii=False, indent=2))
        for name, content in files.items():
            archive.writestr(name, content)
    return {**manifest, 'output': str(output), 'ignored_unchanged': ignored}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--city', required=True)
    parser.add_argument('--source', type=Path, required=True, help='DataFactory checkout')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pack-path', type=Path, help='Explicit Lab working copy, defaults to city assets')
    parser.add_argument('--place-id', action='append', help='Export only selected repair IDs')
    args = parser.parse_args()
    pack = args.pack_path or Path(__file__).resolve().parent.parent / 'assets/city_packs' / args.city
    print(json.dumps(export_patch(pack, args.source, args.output, args.place_id), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()

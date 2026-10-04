"""JSON bridge for desktop operations using the canonical Python tools."""
import argparse
import contextlib
import hashlib
import io
import json
import sqlite3
import sys
from pathlib import Path

from sync_city_packs import discover_releases, sync_packs
from export_certified_pack import export_certified_city_pack
from city_admin_core.certification import _inbox_candidate_changed
from city_admin_core.media_integrity import inspect_manifest
from city_admin_core.identity_conflicts import member_id


def snapshot(pack):
    candidates_path = pack / 'review_candidates.json'
    try:
        candidates = json.loads(candidates_path.read_text(encoding='utf-8')) if candidates_path.is_file() else []
        if not isinstance(candidates, list):
            candidates = []
    except (ValueError, OSError):
        candidates = []
    files = {p.relative_to(pack).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in (pack / 'curation').rglob('*') if p.is_file()}
    count = 0
    if (pack / 'yatracanvas.db').is_file():
        try:
            with contextlib.closing(sqlite3.connect((pack / 'yatracanvas.db').resolve().as_uri()+'?mode=ro', uri=True)) as db:
                count = db.execute('SELECT COUNT(*) FROM places').fetchone()[0]
        except sqlite3.DatabaseError:
            count = 0
    return {'places': count, 'candidates': candidates, 'curation': files}


def run(args):
    root = Path(__file__).resolve().parent.parent
    base = root / 'assets' / 'city_packs'
    if args.operation == 'discover':
        source = Path(args.source).resolve()
        if not (source / 'releases').is_dir():
            raise ValueError('Choose a DataFactory repository containing releases/.')
        return {'cities': [{k: v for k, v in record.items() if k != 'source_path'}
                           for record in discover_releases(source).values()]}
    if args.operation == 'sync':
        available = discover_releases(Path(args.source).resolve())
        if not args.cities or any(city not in available for city in args.cities):
            raise ValueError('Select available city IDs before syncing.')
        before = {city: snapshot(base / city) for city in args.cities}
        sync_packs(args.cities, Path(args.source).resolve(), base)
        results = []
        for city in args.cities:
            previous, after = before[city], snapshot(base / city)
            new = {c['canonical_id']: c for c in after['candidates']}
            old_members = {(c['canonical_id'], member_id(c)): c for c in previous['candidates']}
            new_members = {(c['canonical_id'], member_id(c)): c for c in after['candidates']}
            preserved = [name for name, sha in previous['curation'].items() if after['curation'].get(name) == sha]
            changed_reviews = 0
            corrupt_decisions = 0
            for path in (base / city / 'curation' / 'inbox_decisions').glob('*.json'):
                try:
                    decision = json.loads(path.read_text(encoding='utf-8'))
                    canonical_id = decision['canonical_id']
                except (ValueError, KeyError, TypeError, OSError):
                    corrupt_decisions += 1
                    continue
                candidate = new.get(canonical_id)
                if candidate is None or _inbox_candidate_changed(decision.get('snapshot') or {}, candidate):
                    changed_reviews += 1
            lost = len(previous['curation']) - len(preserved)
            if lost:
                raise RuntimeError(f'{city}: {lost} curation files changed or disappeared')
            results.append({'city': city, 'places_before': previous['places'], 'places_after': after['places'],
                            'candidates_before': len(previous['candidates']), 'candidates_after': len(after['candidates']),
                            'upstream_candidates_changed': sum(old_members.get(k) != new_members.get(k) for k in old_members.keys() | new_members.keys()),
                            'corrupt_decisions_preserved': corrupt_decisions,
                            'decisions_preserved': sum('/inbox_decisions/' in f for f in preserved),
                            'reviewed_records_changed': changed_reviews, 'curation_files_lost': lost})
        return {'results': results}
    if args.operation == 'patch':
        from export_citylab_patch import export_patch
        return export_patch(base / args.city, Path(args.source), Path(args.output), args.place_id)
    if args.operation == 'media':
        reports = {}
        for name in ('image_manifest.json', 'images_manifest.json'):
            path = base / args.city / name
            if path.is_file():
                _, reports[name] = inspect_manifest(json.loads(path.read_text(encoding='utf-8')), path.parent)
        return {'reports': reports}
    result = export_certified_city_pack(args.city, release_evidence=Path(args.evidence), output_dir=Path(args.output))
    return {'city': result.city_id, 'output': str(result.output_dir), 'release': result.release_metadata,
            'integrity': 'PASS', 'media': 'PASS', 'schema': 'PASS'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=('discover', 'sync', 'media', 'build', 'patch'))
    parser.add_argument('--source')
    parser.add_argument('--cities', nargs='+', default=[])
    parser.add_argument('--city')
    parser.add_argument('--evidence')
    parser.add_argument('--output')
    parser.add_argument('--place-id', action='append')
    args = parser.parse_args()
    log = io.StringIO()
    try:
        with contextlib.redirect_stdout(log):
            result = run(args)
        print(json.dumps({'ok': True, **result, 'logs': log.getvalue()}, ensure_ascii=False))
        return 0
    except Exception as exc:
        print(json.dumps({'ok': False, 'error': str(exc), 'logs': log.getvalue()}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    sys.exit(main())

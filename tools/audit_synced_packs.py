"""Read only artifact inventory for the curator workflow audit."""
import collections
import hashlib
import json
from pathlib import Path
import sqlite3
from contextlib import closing


def inspect(base=Path('assets/city_packs')):
    index = json.loads((base / 'city_packs_index.json').read_text(encoding='utf-8'))
    results = {}
    for city in ('jaipur', 'udaipur', 'varanasi'):
        pack = base / city
        manifest = json.loads((pack / 'manifest.json').read_text(encoding='utf-8'))
        candidates = json.loads((pack / 'review_candidates.json').read_text(encoding='utf-8'))
        with closing(sqlite3.connect((pack / 'yatracanvas.db').resolve().as_uri() + '?mode=ro', uri=True)) as db:
            published = db.execute('SELECT COUNT(*) FROM places').fetchone()[0]
            integrity = db.execute('PRAGMA integrity_check').fetchone()[0]
            tables = [row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table'")]
            media = db.execute('SELECT local_path, thumbnail_path, license, author, attribution FROM place_images').fetchall()
        decisions = list((pack / 'curation' / 'inbox_decisions').glob('*.json'))
        results[city] = {
            'published': published, 'candidates': len(candidates),
            'schema': manifest.get('schema_version'), 'version': manifest.get('city_pack_version'),
            'media_records': len(media),
            'missing_media_paths': [path for row in media for path in row[:2] if path and not (pack / path).is_file()],
            'incomplete_media_licenses': [row[0] for row in media if not row[2] or row[2].lower() in ('unknown', 'unverified')],
            'registry_version': index[city]['version'], 'integrity': integrity, 'tables': tables,
            'priority': dict(collections.Counter(c['review_priority'] for c in candidates)),
            'reasons': dict(collections.Counter(c['travel_relevance_reason'] for c in candidates)),
            'duplicate_ids': len(candidates) - len(set(c['canonical_id'] for c in candidates)),
            'colliding_id_groups': sum(count > 1 for count in collections.Counter(c['canonical_id'] for c in candidates).values()),
            'withheld_records': sum(count for count in collections.Counter(c['canonical_id'] for c in candidates).values() if count > 1),
            'files': sorted(p.name for p in pack.iterdir() if p.is_file()),
            'decisions': [json.loads(p.read_text(encoding='utf-8')) for p in decisions],
            'checksum_failures': [name for name, expected in manifest.get('checksums', {}).items()
                                  if (pack / name).is_file() and hashlib.sha256((pack / name).read_bytes()).hexdigest() != expected],
            'priority_samples': {priority: [{k: c.get(k) for k in ('canonical_id', 'name', 'category', 'subcategory', 'tier', 'travel_relevance_reason', 'osm_tags')}
                                             for c in candidates if c['review_priority'] == priority][:20]
                                 for priority in ('HIGH', 'MEDIUM', 'LOW')},
            'searches': {query: sum(query.lower() in c['name'].lower() for c in candidates)
                         for query in ('Lassiwala', 'Mandir', 'Cafe', 'Johari', 'Ghat', 'Temple')},
        }
    return results


if __name__ == '__main__':
    print(json.dumps(inspect(), indent=2, ensure_ascii=False))

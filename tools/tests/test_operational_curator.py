import json
import tempfile
import unittest
import shutil
import sqlite3
import subprocess
import sys
import hashlib
from pathlib import Path
from tools.city_admin_core.media_integrity import inspect_manifest
from tools.city_admin_core.identity_conflicts import member_id, reconcile
from tools.city_admin_core.certification import _inbox_candidate_changed


class OperationalCuratorTest(unittest.TestCase):
    def test_clean_checkout_sync_orchestration_preserves_curation_and_rejects_corrupt_source(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            lab, source = root / 'lab', root / 'factory'
            shutil.copytree(Path('tools'), lab / 'tools', ignore=shutil.ignore_patterns('__pycache__'))
            release = source / 'releases' / 'fixture'
            release.mkdir(parents=True)
            db = sqlite3.connect(release / 'yatracanvas.db')
            db.execute('CREATE TABLE places (id TEXT PRIMARY KEY)')
            db.execute("INSERT INTO places VALUES ('fixture')")
            db.commit()
            db.close()
            (release / 'city.json').write_text('{}')
            (release / 'manifest.json').write_text(json.dumps({'schema_version': '3.0', 'city_id': 'fixture', 'city_name': 'Fixture', 'city_pack_version': 'v3'}))
            (release / 'image_manifest.json').write_text(json.dumps({'fixture': {'gallery': [{'local_path': 'images/missing.webp'}]}}))
            reports = source / 'reports' / 'fixture'
            reports.mkdir(parents=True)
            (reports / 'review_candidates.json').write_text('[]')
            curation = lab / 'assets/city_packs/fixture/curation/inbox_decisions/fixture.json'
            curation.parent.mkdir(parents=True)
            curation.write_text(json.dumps({'canonical_id': 'fixture', 'snapshot': {}, 'verdict': 'NEEDS_RESEARCH'}))
            before = curation.read_bytes()
            command = [sys.executable, str(lab / 'tools/city_lab_operations.py')]
            def run(*args):
                result = subprocess.run([*command, *args], cwd=lab, capture_output=True, text=True, encoding='utf-8')
                return result, json.loads(result.stdout)
            _, discovery = run('discover', '--source', str(source))
            self.assertTrue(discovery['ok'])
            self.assertEqual(discovery['cities'][0]['city_id'], 'fixture')
            _, response = run('sync', '--source', str(source), '--cities', 'fixture')
            self.assertTrue(response['ok'], response)
            self.assertEqual(response['results'][0]['curation_files_lost'], 0)
            self.assertEqual(response['results'][0]['decisions_preserved'], 1)
            self.assertEqual(curation.read_bytes(), before)
            images = json.loads((curation.parents[2] / 'image_manifest.json').read_text())
            self.assertEqual(images['fixture']['gallery'], [])
            local_db = curation.parents[2] / 'yatracanvas.db'
            local_hash = hashlib.sha256(local_db.read_bytes()).hexdigest()
            (release / 'yatracanvas.db').write_bytes(b'corrupt')
            result, response = run('sync', '--source', str(source), '--cities', 'fixture')
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(response['ok'])
            self.assertEqual(hashlib.sha256(local_db.read_bytes()).hexdigest(), local_hash)
            self.assertEqual(curation.read_bytes(), before)

    def test_optional_gallery_pruned_primary_remains_error(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            manifest = {'poi': {'primary': {'local_path': 'missing.webp', 'license': 'CC BY 4.0', 'author': 'Author'},
                                'gallery': [{'local_path': '../escaped.webp', 'license': 'CC BY 4.0', 'author': 'Author'}]}}
            effective, report = inspect_manifest(manifest, root, prune_optional=True)
            self.assertEqual(effective['poi']['gallery'], [])
            self.assertEqual(len(report['missing_primary']), 1)
            self.assertEqual(report['removed_gallery_items'], 1)
            self.assertEqual(len(manifest['poi']['gallery']), 1)

    def test_identity_resolution_survives_reordering_and_reopens_changes(self):
        a = {'canonical_id': 'shared', 'name': 'A', 'latitude': 26.9, 'longitude': 75.8,
             'category': 'cafe', 'external_ids': {'osm': ['node/1']}, 'missing_fields': []}
        b = {**a, 'name': 'B', 'external_ids': {'osm': ['node/2']}}
        record = {'action': 'separate', 'author': 'Curator', 'notes': 'Distinct source entities', 'decided_at': '2026-10-02',
                  'members': {member_id(m): {'missing_fields': [], 'semantic_fields': {'name': m['name']}} for m in (a,b)}}
        effective, errors = reconcile([b, a], {'shared': record}, set(), _inbox_candidate_changed)
        self.assertFalse(errors)
        self.assertEqual(len(effective), 2)
        _, errors = reconcile([{**a, 'name': 'Changed'}, b], {'shared': record}, set(), _inbox_candidate_changed)
        self.assertIn('Changed since conflict resolution', errors[0])
        _, errors = reconcile([a,b], {'shared': record}, {'shared'}, _inbox_candidate_changed)
        self.assertTrue(errors)

    def test_all_real_gallery_references_exist_after_cleanup(self):
        for city in ('jaipur', 'udaipur', 'varanasi'):
            root = Path('assets/city_packs') / city
            manifest = json.loads((root / 'image_manifest.json').read_text(encoding='utf-8'))
            _, report = inspect_manifest(manifest, root)
            self.assertEqual(report['missing_gallery'], [], city)


if __name__ == '__main__':
    unittest.main()

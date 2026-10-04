import json
import tempfile
import unittest
import zipfile
from pathlib import Path
from tools.export_citylab_patch import export_patch, digest


class RepairExportTest(unittest.TestCase):
    def fixture(self,root):
        factory=root/'factory'; source=factory/'releases/india/state/city/v3';source.mkdir(parents=True)
        pack=root/'lab/assets/city_packs/city';pack.mkdir(parents=True)
        city={'id':'city','name':'City','state':'State','country':'India'}
        row={'id':'stable','name':'Original','alternate_names':['Alias'],'city':city,'location':{'latitude':26.9,'longitude':75.8},'classification':{'category':'heritage'},'contact':{},'description':None}
        (source/'city.json').write_text(json.dumps(city));(source/'places.json').write_text(json.dumps([row]))
        (source/'manifest.json').write_text(json.dumps({'generated_at':'2026-10-04'}))
        for file in [source/'yatracanvas.db',pack/'yatracanvas.db']:file.write_bytes(b'fixture identical immutable bytes')
        (pack/'lab_sync_receipt.json').write_text(json.dumps({'source_path':str(source)}))
        overrides=pack/'curation/overrides';overrides.mkdir(parents=True)
        overlay={'place_id':'stable','city_id':'city','pack_version':'v3','description':'Human repair','author':'QA'}
        (overrides/'stable.json').write_text(json.dumps(overlay))
        return factory,source,pack,overlay

    def test_export_base_inventory_and_immutability(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);factory,source,pack,_=self.fixture(root)
            before={p.name:digest(p) for p in source.iterdir()}
            result=export_patch(pack,factory,root/'repair.zip')
            self.assertEqual(result['change_count'],1)
            self.assertEqual(before,{p.name:digest(p) for p in source.iterdir()})
            with zipfile.ZipFile(root/'repair.zip') as archive:
                changes=json.loads(archive.read('changes.json'))
                self.assertIsNone(changes[0]['before']['description'])
                self.assertEqual(changes[0]['changes']['description'],'Human repair')
            with self.assertRaises(ValueError):export_patch(pack,factory,root/'repair.zip')

    def test_stale_overlay_and_changed_baseline_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);factory,source,pack,overlay=self.fixture(root)
            overlay['pack_version']='old'
            (pack/'curation/overrides/stable.json').write_text(json.dumps(overlay))
            with self.assertRaisesRegex(ValueError,'predates'):export_patch(pack,factory,root/'repair.zip')
            (pack/'yatracanvas.db').write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError,'baseline differs'):export_patch(pack,factory,root/'repair.zip')

    def test_invalid_hours_rejected_before_export(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);factory,source,pack,overlay=self.fixture(root)
            overlay['opening_hours']='made-up schedule'
            (pack/'curation/overrides/stable.json').write_text(json.dumps(overlay))
            with self.assertRaisesRegex(ValueError,'hours'):export_patch(pack,factory,root/'repair.zip')

    def test_new_field_review_does_not_promote_old_media(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);factory,source,pack,overlay=self.fixture(root)
            overlay.update(pack_version='old',primary_image_path='../../unsafe-old-photo',field_versions={'description':'v3'})
            (pack/'curation/overrides/stable.json').write_text(json.dumps(overlay))
            report=export_patch(pack,factory,root/'repair.zip')
            self.assertEqual(report['media_count'],0)
            with zipfile.ZipFile(root/'repair.zip') as archive:
                self.assertEqual(set(json.loads(archive.read('changes.json'))[0]['changes']),{'description'})

if __name__=='__main__':unittest.main()

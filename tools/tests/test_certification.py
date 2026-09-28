from __future__ import annotations

import hashlib
import json
import sqlite3
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from tools.city_admin_core import (
    CertificationFailure,
    build_certified_pack,
    publish_certified_pack,
)


class CertificationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.pack = self.root / "pack"
        self.pack.mkdir()
        self._create_database(self.pack / "yatracanvas.db")
        self._write_json(
            self.pack / "manifest.json",
            {
                "schema_version": "3.0",
                "city_pack_version": "v8",
                "city_id": "test_city",
                "city_name": "Test City",
                "state": "Test State",
                "country": "India",
                "generated_at": "2026-09-01T00:00:00Z",
                "counts": {
                    "total_raw_candidates": 10,
                    "accepted": 2,
                    "rejected": 4,
                    "quarantined": 4,
                },
                "checksums": {"yatracanvas.db": "stale-baseline-hash"},
            },
        )
        self._write_json(self.pack / "image_manifest.json", {})
        self._write_json(
            self.root / "ready.json",
            {
                "schema_version": 1,
                "city_id": "test_city",
                "pack_version": "v8",
                "release_gate_status": "READY",
                "manual_qa_passed": True,
                "data_quality_score": 92,
                "travel_readiness_score": 94,
            },
        )
        self._write_valid_curation()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_ready_build_applies_curation_and_regenerates_artifacts(self) -> None:
        """covers: AC-1, AC-4, AC-6, AC-7"""
        source_hash = self._sha(self.pack / "yatracanvas.db")
        output = self.root / "certified"

        result = build_certified_pack(
            pack_dir=self.pack,
            output_dir=output,
            release_evidence_path=self.root / "ready.json",
            now=datetime(2026, 9, 28, 12, 0, tzinfo=timezone.utc),
        )

        self.assertTrue(result.certified)
        self.assertEqual(source_hash, self._sha(self.pack / "yatracanvas.db"))
        connection = sqlite3.connect(output / "yatracanvas.db")
        try:
            rows = connection.execute(
                "SELECT id, name FROM places ORDER BY id"
            ).fetchall()
            integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
        finally:
            connection.close()
        self.assertEqual(
            rows,
            [("manual_addition", "Manual Addition"), ("place_keep", "Human Name")],
        )
        self.assertEqual(integrity, "ok")

        release = self._read_json(output / "release.json")
        manifest = self._read_json(output / "manifest.json")
        checksums = self._read_json(output / "checksums.json")
        self.assertEqual(release["status"], "certified")
        self.assertEqual(release["database_sha256"], self._sha(output / "yatracanvas.db"))
        self.assertEqual(manifest["counts"]["accepted"], 2)
        self.assertEqual(
            manifest["checksums"]["yatracanvas.db"],
            checksums["yatracanvas.db"],
        )
        self.assertEqual(result.reconciliation.applied_overrides, ["place_keep"])
        self.assertEqual(result.reconciliation.applied_additions, ["manual_addition"])
        self.assertEqual(result.reconciliation.applied_exclusions, ["place_remove"])

    def test_blocked_evidence_stops_before_output_is_created(self) -> None:
        """covers: AC-2, AC-8"""
        evidence = self._read_json(self.root / "ready.json")
        evidence["release_gate_status"] = "BLOCKED"
        self._write_json(self.root / "blocked.json", evidence)
        output = self.root / "blocked-output"

        with self.assertRaises(CertificationFailure) as raised:
            build_certified_pack(
                pack_dir=self.pack,
                output_dir=output,
                release_evidence_path=self.root / "blocked.json",
            )

        self.assertIn("requires READY", str(raised.exception))
        self.assertFalse(output.exists())

    def test_review_required_evidence_stops_production_build(self) -> None:
        """covers: AC-2"""
        evidence = self._read_json(self.root / "ready.json")
        evidence["release_gate_status"] = "REVIEW_REQUIRED"
        self._write_json(self.root / "review.json", evidence)

        with self.assertRaises(CertificationFailure) as raised:
            build_certified_pack(
                pack_dir=self.pack,
                output_dir=self.root / "review-output",
                release_evidence_path=self.root / "review.json",
            )

        self.assertIn("REVIEW REQUIRED", str(raised.exception))

    def test_orphaned_override_is_reported_and_not_silently_discarded(self) -> None:
        """covers: AC-5, AC-8"""
        self._write_json(
            self.pack / "curation" / "overrides" / "missing.json",
            {
                "place_id": "missing_place",
                "city_id": "test_city",
                "verified": True,
                "name": "Still Human Work",
            },
        )

        with self.assertRaises(CertificationFailure) as raised:
            build_certified_pack(
                pack_dir=self.pack,
                output_dir=self.root / "orphan-output",
                release_evidence_path=self.root / "ready.json",
            )

        self.assertIn("Orphaned overrides: missing_place", str(raised.exception))
        self.assertTrue(
            (self.pack / "curation" / "overrides" / "missing.json").is_file()
        )

    def test_incomplete_curated_media_attribution_is_a_blocker(self) -> None:
        """covers: AC-6, AC-8"""
        media_path = self.pack / "curation" / "media" / "place_keep.json"
        media = self._read_json(media_path)
        media["sourcePage"] = ""
        self._write_json(media_path, media)

        with self.assertRaises(CertificationFailure) as raised:
            build_certified_pack(
                pack_dir=self.pack,
                output_dir=self.root / "media-output",
                release_evidence_path=self.root / "ready.json",
            )

        self.assertIn("sourcePage", str(raised.exception))

    def test_curated_media_path_cannot_escape_the_pack(self) -> None:
        """covers: AC-6, AC-8"""
        media_path = self.pack / "curation" / "media" / "place_keep.json"
        media = self._read_json(media_path)
        media["primaryImagePath"] = "../outside.webp"
        self._write_json(media_path, media)

        with self.assertRaises(CertificationFailure) as raised:
            build_certified_pack(
                pack_dir=self.pack,
                output_dir=self.root / "escaped-media-output",
                release_evidence_path=self.root / "ready.json",
            )

        self.assertIn("escapes the city pack", str(raised.exception))
        self.assertFalse((self.root / "escaped-media-output").exists())

    def test_force_dev_export_is_local_and_non_certified(self) -> None:
        """covers: AC-3"""
        output = self.root / "dev-output"

        result = build_certified_pack(
            pack_dir=self.pack,
            output_dir=output,
            force_dev_export=True,
        )

        self.assertFalse(result.certified)
        release = self._read_json(output / "release.json")
        self.assertEqual(release["status"], "non_certified")
        self.assertIsNone(release["certified_at"])
        with self.assertRaises(CertificationFailure):
            publish_certified_pack(
                result,
                curation_dir=self.pack / "curation",
                datafactory_root=self.root / "datafactory",
                app_root=self.root / "app",
            )

    def test_ready_artifact_publishes_only_after_local_validation(self) -> None:
        """covers: AC-1, AC-8"""
        result = build_certified_pack(
            pack_dir=self.pack,
            output_dir=self.root / "publish-source",
            release_evidence_path=self.root / "ready.json",
        )

        receipts = publish_certified_pack(
            result,
            curation_dir=self.pack / "curation",
            datafactory_root=self.root / "datafactory",
            app_root=self.root / "app",
        )

        self.assertTrue(
            (self.root / "datafactory" / "data" / "curated" / "test_city").is_dir()
        )
        curated_image = (
            self.root
            / "datafactory"
            / "data"
            / "curated"
            / "test_city"
            / "images"
            / "place_keep"
            / "primary.webp"
        )
        self.assertEqual(curated_image.read_bytes(), b"primary")
        published = self.root / "app" / "assets" / "city_packs" / "test_city"
        self.assertEqual(self._read_json(published / "release.json")["status"], "certified")
        self.assertIn("datafactory_curation", receipts)
        self.assertIn("yatracanvas_pack", receipts)

    def _create_database(self, path: Path) -> None:
        connection = sqlite3.connect(path)
        try:
            connection.executescript(
                """
                CREATE TABLE places (
                    id TEXT PRIMARY KEY,
                    city_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    name_hi TEXT,
                    latitude REAL NOT NULL,
                    longitude REAL NOT NULL,
                    address TEXT,
                    category TEXT NOT NULL,
                    subcategory TEXT,
                    tier TEXT NOT NULL,
                    recommended_visit_minutes INTEGER,
                    family_friendly INTEGER,
                    best_time TEXT,
                    website TEXT,
                    phone TEXT,
                    opening_hours TEXT,
                    wikidata_id TEXT,
                    primary_image_path TEXT,
                    thumbnail_image_path TEXT,
                    generated_at TEXT
                );
                CREATE TABLE place_tags (
                    place_id TEXT NOT NULL,
                    tag TEXT NOT NULL,
                    PRIMARY KEY (place_id, tag)
                );
                CREATE TABLE place_sources (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    place_id TEXT NOT NULL,
                    source TEXT NOT NULL,
                    source_id TEXT,
                    retrieved_at TEXT
                );
                CREATE TABLE place_images (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    place_id TEXT NOT NULL,
                    original_file TEXT NOT NULL,
                    local_path TEXT NOT NULL,
                    thumbnail_path TEXT,
                    author TEXT,
                    license TEXT NOT NULL,
                    license_url TEXT,
                    attribution TEXT,
                    match_method TEXT,
                    match_confidence REAL
                );
                """
            )
            connection.executemany(
                "INSERT INTO places "
                "(id, city_id, name, latitude, longitude, category, tier) "
                "VALUES (?, 'test_city', ?, 26.9, 75.8, 'heritage', 'recommended')",
                [("place_keep", "Provider Name"), ("place_remove", "Remove Me")],
            )
            connection.commit()
        finally:
            connection.close()

    def _write_valid_curation(self) -> None:
        curation = self.pack / "curation"
        self._write_json(
            curation / "overrides" / "place_keep.json",
            {
                "place_id": "place_keep",
                "city_id": "test_city",
                "pack_version": "v8",
                "verified": True,
                "name": "Human Name",
                "opening_hours": "09:00-17:00",
                "author": "Editor",
                "updated_at": "2026-09-28T10:00:00Z",
            },
        )
        self._write_json(
            curation / "additions" / "manual_addition.json",
            {
                "id": "manual_addition",
                "city_id": "test_city",
                "name": "Manual Addition",
                "category": "museum",
                "tier": "recommended",
                "latitude": 26.91,
                "longitude": 75.81,
                "author": "Editor",
                "created_at": "2026-09-28T10:00:00Z",
                "evidence_source": "https://example.test/official",
            },
        )
        self._write_json(
            curation / "exclusions" / "place_remove.json",
            {
                "place_id": "place_remove",
                "city_id": "test_city",
                "place_name": "Remove Me",
                "reason": "closed_permanently",
                "excluded_by": "Editor",
                "timestamp": "2026-09-28T10:00:00Z",
            },
        )
        image_dir = self.pack / "images" / "place_keep"
        image_dir.mkdir(parents=True)
        (image_dir / "primary.webp").write_bytes(b"primary")
        (image_dir / "thumbnail.webp").write_bytes(b"thumbnail")
        self._write_json(
            curation / "media" / "place_keep.json",
            {
                "schemaVersion": 1,
                "cityId": "test_city",
                "placeId": "place_keep",
                "primaryImagePath": "images/place_keep/primary.webp",
                "thumbnailImagePath": "images/place_keep/thumbnail.webp",
                "originalFilename": "official.jpg",
                "originalSha256": "a" * 64,
                "source": "Official tourism board",
                "sourcePage": "https://example.test/photo",
                "author": "Test Photographer",
                "license": "CC BY 4.0",
                "licenseUrl": "https://creativecommons.org/licenses/by/4.0/",
                "originalWidth": 1200,
                "originalHeight": 800,
                "primaryWidth": 1200,
                "primaryHeight": 800,
                "contributor": "Editor",
                "importedAt": "2026-09-28T10:00:00Z",
            },
        )

    @staticmethod
    def _write_json(path: Path, value: object) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value), encoding="utf-8")

    @staticmethod
    def _read_json(path: Path) -> dict:
        return json.loads(path.read_text(encoding="utf-8"))

    @staticmethod
    def _sha(path: Path) -> str:
        return hashlib.sha256(path.read_bytes()).hexdigest()


if __name__ == "__main__":
    unittest.main()

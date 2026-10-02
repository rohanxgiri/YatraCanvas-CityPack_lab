"""Fail closed City Pack curation, validation, and certification."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import sqlite3
import tempfile
import uuid
from contextlib import closing
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable
from .media_integrity import inspect_manifest
from .identity_conflicts import reconcile


class CertificationFailure(RuntimeError):
    """A certification failure with explicit user facing blockers."""

    def __init__(self, blockers: Iterable[str]):
        self.blockers = [str(item) for item in blockers if str(item).strip()]
        super().__init__("Certification failed: " + "; ".join(self.blockers))


@dataclass
class ReconciliationReport:
    applied_overrides: list[str] = field(default_factory=list)
    applied_additions: list[str] = field(default_factory=list)
    applied_exclusions: list[str] = field(default_factory=list)
    applied_media: list[str] = field(default_factory=list)
    orphaned_overrides: list[str] = field(default_factory=list)
    orphaned_exclusions: list[str] = field(default_factory=list)
    orphaned_media: list[str] = field(default_factory=list)
    conflicts: list[str] = field(default_factory=list)

    @property
    def blockers(self) -> list[str]:
        blockers = list(self.conflicts)
        if self.orphaned_overrides:
            blockers.append(
                "Orphaned overrides: " + ", ".join(sorted(self.orphaned_overrides))
            )
        if self.orphaned_exclusions:
            blockers.append(
                "Orphaned exclusions: " + ", ".join(sorted(self.orphaned_exclusions))
            )
        if self.orphaned_media:
            blockers.append(
                "Orphaned media: " + ", ".join(sorted(self.orphaned_media))
            )
        return blockers

    def to_json(self) -> dict[str, Any]:
        result = asdict(self)
        result["needs_human_review"] = bool(self.blockers)
        return result


@dataclass(frozen=True)
class CertificationResult:
    city_id: str
    output_dir: Path
    certified: bool
    release_metadata: dict[str, Any]
    reconciliation: ReconciliationReport
    checksums: dict[str, str]


def _read_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise CertificationFailure([f"Missing {label}: {path}"]) from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise CertificationFailure([f"Invalid {label} at {path}: {exc}"]) from exc
    if not isinstance(value, dict):
        raise CertificationFailure([f"Invalid {label} at {path}: expected a JSON object"])
    return value


def _write_json(path: Path, value: Any) -> None:
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _curation_revision(curation_dir: Path) -> str:
    digest = hashlib.sha256()
    if not curation_dir.is_dir():
        digest.update(b"empty-curation")
        return digest.hexdigest()
    for path in sorted(curation_dir.rglob("*.json")):
        digest.update(path.relative_to(curation_dir).as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def _load_records(directory: Path, label: str) -> list[tuple[Path, dict[str, Any]]]:
    if not directory.is_dir():
        return []
    return [(path, _read_json(path, label)) for path in sorted(directory.glob("*.json"))]


def _value(data: dict[str, Any], snake: str, camel: str | None = None) -> Any:
    if snake in data:
        return data[snake]
    if camel and camel in data:
        return data[camel]
    return None


def _required_text(data: dict[str, Any], field_name: str, source: Path) -> str:
    value = data.get(field_name)
    if not isinstance(value, str) or not value.strip():
        raise CertificationFailure([f"{source}: required field '{field_name}' is empty"])
    return value.strip()


def _normalize_gate_status(evidence: dict[str, Any]) -> str:
    value = (
        evidence.get("release_gate_status")
        or evidence.get("releaseStatus")
        or evidence.get("release_status")
    )
    if value is None and isinstance(evidence.get("release_gate"), dict):
        gate = evidence["release_gate"]
        value = gate.get("display_status") or gate.get("status")
    return str(value or "UNKNOWN").strip().upper().replace("_", " ")


def _manual_qa_passed(evidence: dict[str, Any]) -> bool:
    explicit = evidence.get("manual_qa_passed")
    if isinstance(explicit, bool):
        return explicit
    display = evidence.get("manualQaStatus") or evidence.get("manual_qa_status")
    if isinstance(display, str) and display.strip().upper().startswith("PASSED"):
        return True
    manual = evidence.get("manual_qa")
    if isinstance(manual, dict):
        reviewed = int(manual.get("reviewed_count") or 0)
        minimum = int(manual.get("minimum_required") or 50)
        state = str(manual.get("state") or "").replace("_", "").lower()
        return state == "sufficientsample" and reviewed >= minimum
    return False


def _validate_release_evidence(
    evidence: dict[str, Any], *, city_id: str, pack_version: str
) -> None:
    blockers: list[str] = []
    evidence_city = evidence.get("city_id") or evidence.get("city")
    evidence_version = evidence.get("pack_version") or evidence.get("version")
    if evidence_city != city_id:
        blockers.append(
            f"Release evidence city '{evidence_city}' does not match '{city_id}'."
        )
    if str(evidence_version) != str(pack_version):
        blockers.append(
            f"Release evidence pack version '{evidence_version}' does not match "
            f"source version '{pack_version}'."
        )
    status = _normalize_gate_status(evidence)
    if status != "READY":
        blockers.append(f"Release gate is {status}, production publication requires READY.")
    if not _manual_qa_passed(evidence):
        blockers.append("Manual QA is incomplete or not proven by the release evidence.")
    if blockers:
        raise CertificationFailure(blockers)


def _table_columns(connection: sqlite3.Connection, table: str) -> set[str]:
    return {row[1] for row in connection.execute(f"PRAGMA table_info({table})")}


def _table_exists(connection: sqlite3.Connection, table: str) -> bool:
    return connection.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?", (table,)
    ).fetchone() is not None


def _record_id(data: dict[str, Any], path: Path, *keys: str) -> str:
    for key in keys:
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    raise CertificationFailure([f"{path}: missing entity identifier"])


def _safe_pack_path(pack_root: Path, relative_path: str) -> Path:
    if not isinstance(relative_path, str) or not relative_path.strip():
        raise CertificationFailure(["An image path is empty."])
    candidate = (pack_root / Path(relative_path.replace("/", os.sep))).resolve()
    root = pack_root.resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise CertificationFailure(
            [f"Image path escapes the city pack: {relative_path}"]
        ) from exc
    return candidate


def _inbox_candidate_changed(snapshot: dict[str, Any], candidate: dict[str, Any]) -> bool:
    for key in ('travel_relevance_reason', 'suggested_action'):
        if key in snapshot and snapshot[key] != candidate.get(key):
            return True
    for key in ('travel_relevance_score', 'confidence'):
        if key in snapshot and abs(float(snapshot[key]) - float(candidate.get(key, 0.5))) > 0.05:
            return True
    if set(snapshot.get('missing_fields') or []) != set(candidate.get('missing_fields') or []):
        return True
    semantic = snapshot.get('semantic_fields')
    if semantic is None:
        return False  # Legacy snapshots cannot attest fields never recorded.
    for key, before in semantic.items():
        after = candidate.get(key)
        if key in ('latitude', 'longitude') and isinstance(before, (int, float)) and isinstance(after, (int, float)):
            if abs(before - after) <= 0.0005:
                continue
        if key == 'osm_tags':
            after = {tag: value for tag, value in (after or {}).items()
                     if tag in ('amenity', 'building', 'tourism', 'historic', 'religion',
                                'denomination', 'shop', 'leisure', 'name', 'wikidata')}
        if key == 'external_ids':
            after = {source: sorted(set(ids)) for source, ids in (after or {}).items()}
        if before != after:
            return True
    return False


def _apply_curation(
    database_path: Path,
    curation_dir: Path,
    pack_dir: Path,
    city_id: str,
) -> tuple[ReconciliationReport, dict[str, dict[str, Any]]]:
    report = ReconciliationReport()
    curated_media: dict[str, dict[str, Any]] = {}
    additions = _load_records(curation_dir / "additions", "addition")
    overrides = _load_records(curation_dir / "overrides", "override")
    exclusions = _load_records(curation_dir / "exclusions", "exclusion")
    media_records = _load_records(curation_dir / "media", "media record")
    removed_media_ids = {_record_id(data, path, 'place_id', 'placeId') for path, data in overrides
                         if data.get('verified') is True and data.get('primary_image_path') == ''}

    # Inbox verdicts are the durable store. Adapt them to the existing
    # reconciliation pipeline only in memory, never write duplicate stores.
    inbox = _load_records(curation_dir / "inbox_decisions", "inbox decision")
    manifest_path = pack_dir / "review_candidates.json"
    candidate_map = {}
    if manifest_path.is_file():
        try:
            candidates = json.loads(manifest_path.read_text(encoding="utf-8"))
            if not isinstance(candidates, list):
                raise ValueError("expected a candidate list")
            with closing(sqlite3.connect(database_path)) as identity_db:
                published_ids = {row[0] for row in identity_db.execute('SELECT id FROM places')}
            resolutions = {record['canonical_id']: record for _, record in
                           _load_records(curation_dir / 'identity_conflicts', 'identity conflict')}
            candidate_map, conflicts = reconcile(candidates, resolutions, published_ids, _inbox_candidate_changed)
            report.conflicts.extend(conflicts)
        except (ValueError, KeyError, TypeError) as exc:
            report.conflicts.append(f"Review manifest needs repair: {exc}")
    elif inbox:
        report.conflicts.append("Review manifest missing for saved inbox decisions.")

    connection = sqlite3.connect(database_path)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    try:
        if not _table_exists(connection, "places"):
            raise CertificationFailure(["Certified database is missing the places table."])
        place_columns = _table_columns(connection, "places")
        ids = {row[0] for row in connection.execute("SELECT id FROM places")}
        for path, decision in inbox:
            identifier = _record_id(decision, path, "canonical_id")
            candidate = candidate_map.get(identifier)
            if candidate is None:
                report.conflicts.append(f"{path}: reviewed candidate is missing from the source manifest.")
                continue
            if decision.get('city_id') != city_id:
                report.conflicts.append(f"{path}: decision belongs to another city.")
                continue
            if decision.get('changed_since_review'):
                report.conflicts.append(f"{path}: candidate changed since review.")
                continue
            if _inbox_candidate_changed(decision.get('snapshot') or {}, candidate):
                report.conflicts.append(f"{path}: source evidence changed since review, reopen City Lab and review again.")
                continue
            verdict = decision.get('verdict')
            if verdict not in ('APPROVED', 'EDITED', 'REJECTED'):
                continue
            if verdict == 'REJECTED':
                if identifier in ids:
                    exclusions.append((path, {'place_id': identifier, 'reason': decision.get('verdict_note') or 'Explicit inbox exclusion'}))
                else:
                    report.applied_exclusions.append(identifier)
            elif identifier not in ids and not any(record.get('id') == identifier for _, record in additions):
                additions.append((path, {
                    **candidate, 'id': identifier, 'city_id': city_id,
                    'author': decision.get('author'), 'created_at': decision.get('decided_at'),
                    'evidence_source': f'DataFactory review candidate {identifier}',
                    # Source prose has no description column in v3 SQLite.
                }))
        with connection:
            for path, data in additions:
                place_id = _record_id(data, path, "id", "place_id", "placeId")
                record_city = _value(data, "city_id", "cityId") or city_id
                if record_city != city_id:
                    report.conflicts.append(
                        f"{path}: addition city '{record_city}' does not match '{city_id}'."
                    )
                    continue
                if place_id in ids:
                    report.conflicts.append(
                        f"{path}: addition '{place_id}' conflicts with an existing place."
                    )
                    continue
                try:
                    name = _required_text(data, "name", path)
                    category = _required_text(data, "category", path)
                    author = _required_text(data, "author", path)
                    evidence_source = _required_text(data, "evidence_source", path)
                    latitude = float(data["latitude"])
                    longitude = float(data["longitude"])
                except (KeyError, TypeError, ValueError, CertificationFailure) as exc:
                    report.conflicts.append(f"{path}: invalid required addition value: {exc}")
                    continue
                if not (-90 <= latitude <= 90 and -180 <= longitude <= 180):
                    report.conflicts.append(f"{path}: addition coordinates are invalid.")
                    continue
                candidate = {
                    "id": place_id,
                    "city_id": city_id,
                    "name": name,
                    "name_hi": data.get("name_hi"),
                    "latitude": latitude,
                    "longitude": longitude,
                    "address": data.get("address"),
                    "category": category,
                    "subcategory": data.get("subcategory"),
                    "tier": data.get("tier") or "recommended",
                    "recommended_visit_minutes": data.get("recommended_visit_minutes"),
                    "family_friendly": data.get("family_friendly"),
                    "best_time": data.get("best_time"),
                    "website": data.get("website"),
                    "phone": data.get("phone"),
                    "opening_hours": data.get("opening_hours"),
                    "primary_image_path": data.get("primary_image_path"),
                    "generated_at": data.get("created_at"),
                    "description": data.get("description"),
                    "wikidata_id": data.get("wikidata_id"),
                }
                unsupported = [
                    key
                    for key, value in candidate.items()
                    if value is not None and key not in place_columns
                ]
                if unsupported:
                    report.conflicts.append(
                        f"{path}: database cannot preserve fields: {', '.join(unsupported)}."
                    )
                    continue
                fields = [key for key, value in candidate.items() if value is not None]
                values = [candidate[key] for key in fields]
                placeholders = ", ".join("?" for _ in fields)
                connection.execute(
                    f"INSERT INTO places ({', '.join(fields)}) VALUES ({placeholders})",
                    values,
                )
                if _table_exists(connection, "place_sources"):
                    for source, source_ids in (data.get("external_ids") or {}).items():
                        for source_id in source_ids if isinstance(source_ids, list) else [source_ids]:
                            connection.execute(
                                "INSERT INTO place_sources (place_id, source, source_id, retrieved_at) VALUES (?, ?, ?, ?)",
                                (place_id, source, str(source_id), data.get("created_at") or author),
                            )
                    connection.execute(
                        "INSERT INTO place_sources "
                        "(place_id, source, source_id, retrieved_at) VALUES (?, ?, ?, ?)",
                        (
                            place_id,
                            "manual_curation",
                            evidence_source,
                            data.get("created_at") or author,
                        ),
                    )
                ids.add(place_id)
                report.applied_additions.append(place_id)

            override_fields = {
                "name": "name",
                "name_hi": "name_hi",
                "category": "category",
                "subcategory": "subcategory",
                "latitude": "latitude",
                "longitude": "longitude",
                "address": "address",
                "opening_hours": "opening_hours",
                "website": "website",
                "phone": "phone",
                "description": "description",
                "primary_image_path": "primary_image_path",
                "tier": "tier",
            }
            for path, data in overrides:
                place_id = _record_id(data, path, "place_id", "placeId")
                if data.get("verified") is not True:
                    report.conflicts.append(f"{path}: override is not verified.")
                    continue
                if place_id not in ids:
                    report.orphaned_overrides.append(place_id)
                    continue
                updates: list[str] = []
                values: list[Any] = []
                for json_field, db_field in override_fields.items():
                    if json_field not in data or data[json_field] is None:
                        continue
                    if db_field not in place_columns:
                        report.conflicts.append(
                            f"{path}: database cannot preserve override field '{json_field}'."
                        )
                        continue
                    updates.append(f"{db_field} = ?")
                    values.append(data[json_field])
                if data.get("is_core") is True and "tier" not in data:
                    updates.append("tier = ?")
                    values.append("core_destination")
                elif data.get("is_core") is False and "tier" not in data:
                    report.conflicts.append(
                        f"{path}: is_core=false requires an explicit replacement tier."
                    )
                if updates:
                    values.append(place_id)
                    connection.execute(
                        f"UPDATE places SET {', '.join(updates)} WHERE id = ?", values
                    )
                    report.applied_overrides.append(place_id)
                    if data.get('primary_image_path') == '':
                        if 'thumbnail_image_path' in place_columns:
                            connection.execute('UPDATE places SET thumbnail_image_path = NULL WHERE id = ?', (place_id,))
                        if _table_exists(connection, 'place_images'):
                            connection.execute('DELETE FROM place_images WHERE place_id = ?', (place_id,))

            for path, data in exclusions:
                place_id = _record_id(data, path, "place_id", "placeId")
                try:
                    _required_text(data, "reason", path)
                except CertificationFailure as exc:
                    report.conflicts.extend(exc.blockers)
                    continue
                if place_id not in ids:
                    report.orphaned_exclusions.append(place_id)
                    continue
                for child_table in ("place_tags", "place_images", "place_sources"):
                    if _table_exists(connection, child_table):
                        connection.execute(
                            f"DELETE FROM {child_table} WHERE place_id = ?", (place_id,)
                        )
                connection.execute("DELETE FROM places WHERE id = ?", (place_id,))
                ids.remove(place_id)
                report.applied_exclusions.append(place_id)

            for path, data in media_records:
                place_id = _record_id(data, path, "place_id", "placeId")
                if place_id in removed_media_ids:
                    continue
                if place_id not in ids:
                    report.orphaned_media.append(place_id)
                    continue
                required = (
                    "primaryImagePath",
                    "thumbnailImagePath",
                    "originalFilename",
                    "originalSha256",
                    "source",
                    "sourcePage",
                    "author",
                    "license",
                    "licenseUrl",
                    "contributor",
                    "importedAt",
                )
                missing = [
                    name
                    for name in required
                    if not isinstance(data.get(name), str) or not data[name].strip()
                ]
                if data.get('source', '').strip().lower() == 'own work' and 'sourcePage' in missing:
                    missing.remove('sourcePage')
                for dimension in (
                    "originalWidth",
                    "originalHeight",
                    "primaryWidth",
                    "primaryHeight",
                ):
                    if not isinstance(data.get(dimension), int) or data[dimension] <= 0:
                        missing.append(dimension)
                sha = str(data.get("originalSha256") or "")
                if len(sha) != 64 or any(c not in "0123456789abcdefABCDEF" for c in sha):
                    missing.append("originalSha256(valid SHA 256)")
                if missing:
                    report.conflicts.append(
                        f"{path}: incomplete media metadata: {', '.join(sorted(set(missing)))}."
                    )
                    continue
                try:
                    primary = _safe_pack_path(pack_dir, data["primaryImagePath"])
                    thumbnail = _safe_pack_path(pack_dir, data["thumbnailImagePath"])
                except CertificationFailure as exc:
                    report.conflicts.extend(exc.blockers)
                    continue
                absent = [str(item) for item in (primary, thumbnail) if not item.is_file()]
                if absent:
                    report.conflicts.append(
                        f"{path}: curated image files are missing: {', '.join(absent)}."
                    )
                    continue
                connection.execute(
                    "UPDATE places SET primary_image_path = ?, thumbnail_image_path = ? "
                    "WHERE id = ?",
                    (data["primaryImagePath"], data["thumbnailImagePath"], place_id),
                )
                if _table_exists(connection, "place_images"):
                    connection.execute(
                        "DELETE FROM place_images WHERE place_id = ? AND local_path = ?",
                        (place_id, data["primaryImagePath"]),
                    )
                    connection.execute(
                        "INSERT INTO place_images "
                        "(place_id, original_file, local_path, thumbnail_path, author, "
                        "license, license_url, attribution, match_method, match_confidence) "
                        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                        (
                            place_id,
                            data["originalFilename"],
                            data["primaryImagePath"],
                            data["thumbnailImagePath"],
                            data["author"],
                            data["license"],
                            data["licenseUrl"],
                            f"{data['author']} via {data['source']} ({data['sourcePage']})",
                            "verified_human_curation",
                            1.0,
                        ),
                    )
                curated_media[place_id] = data
                report.applied_media.append(place_id)
    finally:
        connection.close()
    if report.blockers:
        raise CertificationFailure(report.blockers)
    return report, curated_media


def _validate_database_and_media(database_path: Path, artifact_dir: Path) -> None:
    blockers: list[str] = []
    connection = sqlite3.connect(database_path)
    try:
        integrity = connection.execute("PRAGMA integrity_check").fetchone()
        if not integrity or integrity[0] != "ok":
            blockers.append(f"SQLite integrity check failed: {integrity}")
        for row in connection.execute(
            "SELECT id, primary_image_path, thumbnail_image_path FROM places "
            "WHERE COALESCE(primary_image_path, '') <> '' "
            "OR COALESCE(thumbnail_image_path, '') <> ''"
        ):
            for relative_path in row[1:]:
                if not relative_path:
                    continue
                try:
                    resolved = _safe_pack_path(artifact_dir, relative_path)
                    if not resolved.is_file():
                        blockers.append(
                            f"Place {row[0]} references missing image {relative_path}."
                        )
                except CertificationFailure as exc:
                    blockers.extend(exc.blockers)
        if _table_exists(connection, "place_images"):
            for row in connection.execute(
                "SELECT place_id, local_path, thumbnail_path, license FROM place_images"
            ):
                if not str(row[3] or "").strip():
                    blockers.append(f"Media for place {row[0]} has no licence.")
                for relative_path in row[1:3]:
                    if not relative_path:
                        continue
                    try:
                        resolved = _safe_pack_path(artifact_dir, relative_path)
                        if not resolved.is_file():
                            blockers.append(
                                f"Media for place {row[0]} is missing {relative_path}."
                            )
                    except CertificationFailure as exc:
                        blockers.extend(exc.blockers)
    finally:
        connection.close()
    if blockers:
        raise CertificationFailure(blockers)


def _query_counts(database_path: Path) -> dict[str, Any]:
    connection = sqlite3.connect(database_path)
    try:
        total = connection.execute("SELECT COUNT(*) FROM places").fetchone()[0]
        with_images = connection.execute(
            "SELECT COUNT(*) FROM places WHERE COALESCE(primary_image_path, '') <> ''"
        ).fetchone()[0]
        with_hours = connection.execute(
            "SELECT COUNT(*) FROM places WHERE COALESCE(opening_hours, '') <> ''"
        ).fetchone()[0]
        with_wikidata = connection.execute(
            "SELECT COUNT(*) FROM places WHERE COALESCE(wikidata_id, '') <> ''"
        ).fetchone()[0]
        by_tier = dict(
            connection.execute(
                "SELECT tier, COUNT(*) FROM places GROUP BY tier ORDER BY tier"
            ).fetchall()
        )
        by_category = dict(
            connection.execute(
                "SELECT category, COUNT(*) FROM places GROUP BY category ORDER BY category"
            ).fetchall()
        )
        by_tier_stats: dict[str, dict[str, int]] = {}
        for tier in by_tier:
            row = connection.execute(
                "SELECT COUNT(*), "
                "SUM(CASE WHEN COALESCE(wikidata_id, '') <> '' THEN 1 ELSE 0 END), "
                "SUM(CASE WHEN COALESCE(primary_image_path, '') <> '' THEN 1 ELSE 0 END), "
                "SUM(CASE WHEN COALESCE(opening_hours, '') <> '' THEN 1 ELSE 0 END), "
                "SUM(CASE WHEN COALESCE(website, '') <> '' THEN 1 ELSE 0 END) "
                "FROM places WHERE tier = ?",
                (tier,),
            ).fetchone()
            multi_source = 0
            if _table_exists(connection, "place_sources"):
                multi_source = connection.execute(
                    "SELECT COUNT(*) FROM ("
                    "SELECT p.id FROM places p JOIN place_sources s ON s.place_id = p.id "
                    "WHERE p.tier = ? GROUP BY p.id HAVING COUNT(DISTINCT s.source) >= 2)",
                    (tier,),
                ).fetchone()[0]
            by_tier_stats[str(tier)] = {
                "count": int(row[0] or 0),
                "with_wikidata": int(row[1] or 0),
                "with_image": int(row[2] or 0),
                "with_hours": int(row[3] or 0),
                "with_website": int(row[4] or 0),
                "multi_source": int(multi_source or 0),
            }
        return {
            "accepted": int(total),
            "with_images": int(with_images),
            "with_opening_hours": int(with_hours),
            "with_wikidata": int(with_wikidata),
            "by_tier": {str(k): int(v) for k, v in by_tier.items()},
            "by_tier_stats": by_tier_stats,
            "by_category": {str(k): int(v) for k, v in by_category.items()},
            "opening_hours_coverage": round(with_hours / total, 6) if total else 0.0,
            "image_coverage": round(with_images / total, 6) if total else 0.0,
        }
    finally:
        connection.close()


def _merge_image_manifest(
    baseline: dict[str, Any],
    curated_media: dict[str, dict[str, Any]],
    active_ids: set[str],
) -> dict[str, Any]:
    merged = {key: value for key, value in baseline.items() if key in active_ids}
    for place_id, data in curated_media.items():
        merged[place_id] = {
            "primary": {
                "source": data["source"],
                "source_page": data["sourcePage"],
                "original_file": data["originalFilename"],
                "original_sha256": data["originalSha256"],
                "author": data["author"],
                "license": data["license"],
                "license_url": data["licenseUrl"],
                "attribution": f"{data['author']} via {data['source']}",
                "width": data["primaryWidth"],
                "height": data["primaryHeight"],
                "match_method": "verified_human_curation",
                "match_confidence": 1.0,
                "downloaded_at": data["importedAt"],
                "local_path": data["primaryImagePath"],
                "thumbnail_path": data["thumbnailImagePath"],
                "contributor": data["contributor"],
            },
            "gallery": [],
        }
    return merged


def _artifact_checksums(root: Path) -> dict[str, str]:
    checksums: dict[str, str] = {}
    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        relative = path.relative_to(root).as_posix()
        if relative != "checksums.json":
            checksums[relative] = _sha256(path)
    return checksums


def build_certified_pack(
    *,
    pack_dir: Path,
    output_dir: Path,
    release_evidence_path: Path | None = None,
    force_dev_export: bool = False,
    now: datetime | None = None,
) -> CertificationResult:
    """Build and validate one local release artifact without publishing it."""

    pack_dir = pack_dir.resolve()
    output_dir = output_dir.resolve()
    source_database = pack_dir / "yatracanvas.db"
    baseline_manifest = _read_json(pack_dir / "manifest.json", "source manifest")
    if not source_database.is_file():
        raise CertificationFailure([f"Missing source database: {source_database}"])
    city_id = str(baseline_manifest.get("city_id") or pack_dir.name)
    pack_version = str(baseline_manifest.get("city_pack_version") or "unknown")
    evidence = (
        _read_json(release_evidence_path, "release evidence")
        if release_evidence_path is not None
        else {}
    )
    if not force_dev_export:
        if release_evidence_path is None:
            raise CertificationFailure(
                ["Production certification requires --release-evidence from CityPack Lab."]
            )
        _validate_release_evidence(evidence, city_id=city_id, pack_version=pack_version)
    if output_dir.exists():
        raise CertificationFailure(
            [f"Output directory already exists and was not changed: {output_dir}"]
        )

    output_dir.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(
        tempfile.mkdtemp(prefix=f".{city_id}-certification-", dir=output_dir.parent)
    )
    curation_dir = pack_dir / "curation"
    revision = _curation_revision(curation_dir)
    timestamp = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    generated_at = timestamp.isoformat().replace("+00:00", "Z")
    try:
        shutil.copy2(source_database, staging / "yatracanvas.db")
        if (pack_dir / "images").is_dir():
            shutil.copytree(pack_dir / "images", staging / "images")
        for name in ("city.json", "source_manifest.json", "license_manifest.json"):
            if (pack_dir / name).is_file():
                shutil.copy2(pack_dir / name, staging / name)

        report, curated_media = _apply_curation(
            staging / "yatracanvas.db", curation_dir, pack_dir, city_id
        )
        # The source SQLite is immutable and may still contain optional gallery
        # rows for files omitted upstream. Prune those rows in the output copy.
        with closing(sqlite3.connect(staging / 'yatracanvas.db')) as media_connection:
            if _table_exists(media_connection, 'place_images'):
                rows = media_connection.execute(
                    'SELECT i.rowid, i.local_path, p.primary_image_path FROM place_images i '
                    'JOIN places p ON p.id = i.place_id').fetchall()
                for row_id, local_path, primary_path in rows:
                    if local_path != primary_path and (not local_path or not (staging / local_path).is_file()):
                        media_connection.execute('DELETE FROM place_images WHERE rowid = ?', (row_id,))
                media_connection.commit()
        _validate_database_and_media(staging / "yatracanvas.db", staging)
        connection = sqlite3.connect(staging / "yatracanvas.db")
        try:
            active_ids = {row[0] for row in connection.execute("SELECT id FROM places")}
            media_ids = {row[0] for row in connection.execute("SELECT id FROM places WHERE COALESCE(primary_image_path, '') <> ''")}
        finally:
            connection.close()
        baseline_image_path = pack_dir / "image_manifest.json"
        if not baseline_image_path.is_file():
            baseline_image_path = pack_dir / "images_manifest.json"
        baseline_images = (
            _read_json(baseline_image_path, "image manifest")
            if baseline_image_path.is_file()
            else {}
        )
        effective_images, media_report = inspect_manifest(
            _merge_image_manifest(baseline_images, curated_media, media_ids), staging,
            prune_optional=True)
        media_blockers = media_report['missing_primary'] + media_report['metadata_errors']
        if media_blockers:
            raise CertificationFailure(media_blockers)
        _write_json(staging / 'image_manifest.json', effective_images)
        _write_json(staging / 'media_validation.json', media_report)

        actual_counts = _query_counts(staging / "yatracanvas.db")
        counts = dict(baseline_manifest.get("counts") or {})
        counts.update(actual_counts)
        database_sha = _sha256(staging / "yatracanvas.db")
        manifest_checksums = {
            "yatracanvas.db": database_sha,
            "image_manifest.json": _sha256(staging / "image_manifest.json"),
        }
        for name in ("city.json", "source_manifest.json", "license_manifest.json"):
            if (staging / name).is_file():
                manifest_checksums[name] = _sha256(staging / name)
        manifest = dict(baseline_manifest)
        manifest.update(
            {
                "city_id": city_id,
                "city_pack_version": pack_version,
                "published_at": generated_at,
                "release_source": "citypack_lab",
                "release_status": "non_certified" if force_dev_export else "certified",
                "curation_revision": revision,
                "counts": counts,
                "curation": report.to_json(),
                "checksums": manifest_checksums,
            }
        )
        _write_json(staging / "manifest.json", manifest)
        release = {
            "schema_version": 1,
            "city_id": city_id,
            "pack_version": pack_version,
            "source_schema_version": baseline_manifest.get("schema_version"),
            "curation_revision": revision,
            "status": "non_certified" if force_dev_export else "certified",
            "certified_at": None if force_dev_export else generated_at,
            "generated_at": generated_at,
            "release_source": "citypack_lab",
            "release_gate_status": _normalize_gate_status(evidence),
            "data_quality_score": evidence.get("data_quality_score")
            or evidence.get("dataQualityScore"),
            "travel_readiness_score": evidence.get("travel_readiness_score")
            or evidence.get("travelReadinessScore"),
            "manual_qa_passed": _manual_qa_passed(evidence),
            "database_sha256": database_sha,
            "place_count": actual_counts["accepted"],
            "image_count": actual_counts["with_images"],
            "opening_hours_coverage": actual_counts["opening_hours_coverage"],
            "development_override": force_dev_export,
            "reconciliation": report.to_json(),
        }
        _write_json(staging / "release.json", release)
        checksums = _artifact_checksums(staging)
        _write_json(staging / "checksums.json", checksums)
        if checksums.get("yatracanvas.db") != database_sha:
            raise CertificationFailure(
                ["Generated database checksum does not match the release descriptor."]
            )
        os.replace(staging, output_dir)
        return CertificationResult(
            city_id=city_id,
            output_dir=output_dir,
            certified=not force_dev_export,
            release_metadata=release,
            reconciliation=report,
            checksums=checksums,
        )
    except Exception:
        if staging.exists():
            shutil.rmtree(staging, ignore_errors=True)
        raise


def _prepare_tree(source: Path, target: Path) -> Path:
    target.parent.mkdir(parents=True, exist_ok=True)
    stage = target.parent / f".{target.name}.stage-{uuid.uuid4().hex}"
    shutil.copytree(source, stage)
    return stage


def _prepare_datafactory_curation_bundle(
    result: CertificationResult, curation_dir: Path
) -> Path:
    """Create a portable curation tree, including every referenced curated image."""

    bundle = result.output_dir.parent / (
        f".{result.city_id}-curation-bundle-{uuid.uuid4().hex}"
    )
    shutil.copytree(curation_dir, bundle)
    try:
        for record_path, data in _load_records(bundle / "media", "media record"):
            for field_name in ("primaryImagePath", "thumbnailImagePath"):
                relative_path = data.get(field_name)
                if not isinstance(relative_path, str) or not relative_path.strip():
                    raise CertificationFailure(
                        [f"{record_path}: required field '{field_name}' is empty"]
                    )
                source = _safe_pack_path(result.output_dir, relative_path)
                if not source.is_file():
                    raise CertificationFailure(
                        [f"Certified artifact is missing curated media: {relative_path}"]
                    )
                destination = _safe_pack_path(bundle, relative_path)
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, destination)
        return bundle
    except Exception:
        shutil.rmtree(bundle, ignore_errors=True)
        raise


def publish_certified_pack(
    result: CertificationResult,
    *,
    curation_dir: Path,
    datafactory_root: Path,
    app_root: Path,
) -> dict[str, str]:
    """Publish a certified artifact with staged target swaps and rollback."""

    if not result.certified or result.release_metadata.get("status") != "certified":
        raise CertificationFailure(["A non certified development artifact cannot be published."])
    if not curation_dir.is_dir():
        raise CertificationFailure([f"Curation directory is missing: {curation_dir}"])
    curation_bundle = _prepare_datafactory_curation_bundle(result, curation_dir)
    targets = [
        (
            curation_bundle,
            datafactory_root / "data" / "curated" / result.city_id,
            "datafactory_curation",
        ),
        (
            result.output_dir,
            app_root / "assets" / "city_packs" / result.city_id,
            "yatracanvas_pack",
        ),
    ]
    prepared: list[tuple[Path, Path, str]] = []
    backups: list[tuple[Path, Path]] = []
    installed: list[Path] = []
    try:
        for source, target, label in targets:
            prepared.append((_prepare_tree(source, target), target, label))
        for stage, target, _ in prepared:
            if target.exists():
                backup = target.parent / f".{target.name}.backup-{uuid.uuid4().hex}"
                os.replace(target, backup)
                backups.append((backup, target))
            os.replace(stage, target)
            installed.append(target)
        for backup, _ in backups:
            shutil.rmtree(backup)
        return {label: str(target) for _, target, label in prepared}
    except Exception as exc:
        for target in reversed(installed):
            if target.exists():
                shutil.rmtree(target, ignore_errors=True)
        for backup, target in reversed(backups):
            if backup.exists():
                os.replace(backup, target)
        raise CertificationFailure([f"Publication failed and was rolled back: {exc}"]) from exc
    finally:
        for stage, _, _ in prepared:
            if stage.exists():
                shutil.rmtree(stage, ignore_errors=True)
        if curation_bundle.exists():
            shutil.rmtree(curation_bundle, ignore_errors=True)

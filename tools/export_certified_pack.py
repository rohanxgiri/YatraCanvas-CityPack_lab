#!/usr/bin/env python3
"""Build, validate, and optionally publish one certified City Pack."""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

from city_admin_core import (
    CertificationFailure,
    build_certified_pack,
    publish_certified_pack,
)


def find_sibling_repo(repo_name: str) -> Path | None:
    candidates = [
        Path.cwd().parent / repo_name,
        Path(__file__).resolve().parent.parent.parent / repo_name,
        Path.home() / "Documents" / repo_name,
    ]
    for candidate in candidates:
        if candidate.is_dir():
            return candidate.resolve()
    return None


def _default_output(lab_root: Path, city_id: str) -> Path:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return lab_root / "releases" / city_id / stamp


def export_certified_city_pack(
    city_id: str,
    *,
    release_evidence: Path | None = None,
    output_dir: Path | None = None,
    force_dev_export: bool = False,
    publish: bool = False,
):
    lab_root = Path(__file__).resolve().parent.parent
    pack_dir = lab_root / "assets" / "city_packs" / city_id
    if not pack_dir.is_dir():
        raise CertificationFailure([f"City pack '{city_id}' was not found at {pack_dir}"])
    if force_dev_export and publish:
        raise CertificationFailure(["--force-dev-export cannot be combined with --publish."])

    result = build_certified_pack(
        pack_dir=pack_dir,
        output_dir=output_dir or _default_output(lab_root, city_id),
        release_evidence_path=release_evidence,
        force_dev_export=force_dev_export,
    )

    receipts: dict[str, str] = {}
    if publish:
        datafactory_root = find_sibling_repo("YatraCanvas-DataFactory")
        app_root = find_sibling_repo("YatraCanvas")
        missing = []
        if datafactory_root is None:
            missing.append("YatraCanvas-DataFactory")
        if app_root is None:
            missing.append("YatraCanvas")
        if missing:
            raise CertificationFailure(
                ["Cannot publish because sibling repositories are missing: " + ", ".join(missing)]
            )
        receipts = publish_certified_pack(
            result,
            curation_dir=pack_dir / "curation",
            datafactory_root=datafactory_root,
            app_root=app_root,
        )

    print("\nCITY PACK CERTIFICATION")
    print(f"City: {result.city_id}")
    print(f"Status: {result.release_metadata['status']}")
    print(f"Artifact: {result.output_dir}")
    print(f"Database SHA-256: {result.release_metadata['database_sha256']}")
    print(
        "Reconciliation: "
        f"{len(result.reconciliation.applied_overrides)} overrides, "
        f"{len(result.reconciliation.applied_additions)} additions, "
        f"{len(result.reconciliation.applied_exclusions)} exclusions, "
        f"{len(result.reconciliation.applied_media)} media records"
    )
    if force_dev_export:
        print("WARNING: developer override output is NON CERTIFIED and was not published.")
    for name, path in receipts.items():
        print(f"Published {name}: {path}")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build and optionally publish a validated City Pack."
    )
    parser.add_argument("--city", default="jaipur", help="City ID")
    parser.add_argument(
        "--release-evidence",
        type=Path,
        help="CityPack Lab release.json. Required for certified output.",
    )
    parser.add_argument(
        "--output-dir", type=Path, help="New local artifact directory."
    )
    parser.add_argument(
        "--force-dev-export",
        action="store_true",
        help="Create a local non certified artifact without READY evidence.",
    )
    parser.add_argument(
        "--publish",
        action="store_true",
        help="After certification, publish to DataFactory and YatraCanvas siblings.",
    )
    args = parser.parse_args()
    try:
        export_certified_city_pack(
            args.city.lower(),
            release_evidence=args.release_evidence,
            output_dir=args.output_dir,
            force_dev_export=args.force_dev_export,
            publish=args.publish,
        )
        return 0
    except CertificationFailure as exc:
        print("\nCertification failed", file=sys.stderr)
        for index, blocker in enumerate(exc.blockers, start=1):
            print(f"{index}. {blocker}", file=sys.stderr)
        print("Pack was NOT published.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""
tools/summarize_curation.py

Generates a PR-friendly Markdown summary and console report of all human curation
changes stored in assets/city_packs/<cityId>/curation/.

Tracks:
- Field overrides (images, opening hours, coordinates, category, name, etc.)
- Manually added POIs
- Manually excluded places (with reasons)
- Manual QA reviews (approved vs rejected)
- Curation issues (open, fixed, verified, ignored)
"""

import os
import sys
import json
import argparse
from pathlib import Path

# Ensure UTF-8 output on Windows
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")


def summarize_city_curation(curation_dir: Path, city_name: str) -> dict:
    summary = {
        "city": city_name,
        "total_changes": 0,
        "overrides_by_field": {},
        "total_overrides": 0,
        "additions": [],
        "exclusions": [],
        "reviews": {"approved": 0, "rejected": 0, "total": 0},
        "issues": {"open": 0, "fixed": 0, "verified": 0, "ignored": 0, "total": 0},
    }

    if not curation_dir.is_dir():
        return summary

    # 1. Overrides
    overrides_dir = curation_dir / "overrides"
    if overrides_dir.is_dir():
        for f in overrides_dir.glob("*.json"):
            try:
                with open(f, "r", encoding="utf-8") as fp:
                    data = json.load(fp)
                    field = data.get("field", "unknown")
                    summary["overrides_by_field"][field] = summary["overrides_by_field"].get(field, 0) + 1
                    summary["total_overrides"] += 1
            except Exception as e:
                print(f"Warning: Failed to parse override {f}: {e}", file=sys.stderr)

    # 2. Additions
    additions_dir = curation_dir / "additions"
    if additions_dir.is_dir():
        for f in additions_dir.glob("*.json"):
            try:
                with open(f, "r", encoding="utf-8") as fp:
                    data = json.load(fp)
                    summary["additions"].append({
                        "id": data.get("placeId"),
                        "name": data.get("name"),
                        "category": data.get("category"),
                        "isCore": data.get("isCore", False),
                    })
            except Exception as e:
                print(f"Warning: Failed to parse addition {f}: {e}", file=sys.stderr)

    # 3. Exclusions
    exclusions_dir = curation_dir / "exclusions"
    if exclusions_dir.is_dir():
        for f in exclusions_dir.glob("*.json"):
            try:
                with open(f, "r", encoding="utf-8") as fp:
                    data = json.load(fp)
                    summary["exclusions"].append({
                        "id": data.get("placeId"),
                        "name": data.get("placeName"),
                        "reason": data.get("reason"),
                    })
            except Exception as e:
                print(f"Warning: Failed to parse exclusion {f}: {e}", file=sys.stderr)

    # 4. Reviews
    reviews_dir = curation_dir / "reviews"
    if reviews_dir.is_dir():
        for f in reviews_dir.glob("*.json"):
            try:
                with open(f, "r", encoding="utf-8") as fp:
                    data = json.load(fp)
                    is_approved = data.get("isApproved", False)
                    if is_approved:
                        summary["reviews"]["approved"] += 1
                    else:
                        summary["reviews"]["rejected"] += 1
                    summary["reviews"]["total"] += 1
            except Exception as e:
                print(f"Warning: Failed to parse review {f}: {e}", file=sys.stderr)

    # 5. Issues
    issues_dir = curation_dir / "issues"
    if issues_dir.is_dir():
        for f in issues_dir.glob("*.json"):
            try:
                with open(f, "r", encoding="utf-8") as fp:
                    data = json.load(fp)
                    status = data.get("status", "open")
                    if status in summary["issues"]:
                        summary["issues"][status] += 1
                    summary["issues"]["total"] += 1
            except Exception as e:
                print(f"Warning: Failed to parse issue {f}: {e}", file=sys.stderr)

    summary["total_changes"] = (
        summary["total_overrides"]
        + len(summary["additions"])
        + len(summary["exclusions"])
    )
    return summary


def format_markdown_summary(summary: dict) -> str:
    city_cap = summary["city"].capitalize()
    lines = []
    lines.append(f"## {city_cap} Curation Summary")
    lines.append("")
    lines.append(f"**Total Curation Changes:** {summary['total_changes']}")
    lines.append("")

    if summary["total_overrides"] > 0:
        lines.append("### Field Overrides")
        lines.append("| Field | Count |")
        lines.append("|---|---|")
        for field, count in sorted(summary["overrides_by_field"].items()):
            field_name = field.replace("_", " ").title()
            lines.append(f"| {field_name} | {count} |")
        lines.append("")

    if summary["additions"]:
        lines.append(f"### Manually Added Places ({len(summary['additions'])})")
        lines.append("| Name | Category | Tier | ID |")
        lines.append("|---|---|---|---|")
        for add in summary["additions"]:
            tier = "Core" if add["isCore"] else "Standard"
            lines.append(f"| {add['name']} | {add['category']} | {tier} | `{add['id']}` |")
        lines.append("")

    if summary["exclusions"]:
        lines.append(f"### Manually Excluded Places ({len(summary['exclusions'])})")
        lines.append("| Name | Reason | ID |")
        lines.append("|---|---|---|")
        for ex in summary["exclusions"]:
            name = ex["name"] or "Unknown"
            lines.append(f"| {name} | {ex['reason']} | `{ex['id']}` |")
        lines.append("")

    lines.append("### Manual QA & Verification")
    rev = summary["reviews"]
    lines.append(f"- **Total Reviews Completed:** {rev['total']}")
    lines.append(f"  - Approved: {rev['approved']}")
    lines.append(f"  - Flagged / Rejected: {rev['rejected']}")
    lines.append("")

    lines.append("### Curation Issues")
    iss = summary["issues"]
    lines.append(f"- **Total Issues Tracked:** {iss['total']}")
    lines.append(f"  - Open: {iss['open']}")
    lines.append(f"  - Fixed: {iss['fixed']}")
    lines.append(f"  - Verified: {iss['verified']}")
    lines.append(f"  - Ignored: {iss['ignored']}")
    lines.append("")

    lines.append("---")
    lines.append("*Generated by YatraCanvas City Pack Curation Studio*")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Summarize human curation changes for City Packs.")
    parser.add_argument("--city", default="jaipur", help="City ID (default: jaipur)")
    parser.add_argument("--all", action="store_true", help="Summarize all available city packs")
    parser.add_argument("--output", help="Optional output markdown file path (e.g. curation_summary.md)")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    packs_dir = repo_root / "assets" / "city_packs"

    if args.all:
        cities = [p.name for p in packs_dir.iterdir() if p.is_dir() and (p / "yatracanvas.db").is_file()]
    else:
        cities = [args.city.lower()]

    full_output = []
    for city in cities:
        curation_path = packs_dir / city / "curation"
        summary = summarize_city_curation(curation_path, city)
        md = format_markdown_summary(summary)
        full_output.append(md)
        print(f"\n[{city.upper()}] Total changes: {summary['total_changes']}, Overrides: {summary['total_overrides']}, Added: {len(summary['additions'])}, Excluded: {len(summary['exclusions'])}, Reviews: {summary['reviews']['total']}")

    combined_md = "\n\n".join(full_output)

    if args.output:
        out_path = Path(args.output).resolve()
        with open(out_path, "w", encoding="utf-8") as fp:
            fp.write(combined_md)
        print(f"\nWritten curation summary to {out_path}")
    else:
        default_out = repo_root / "curation_summary.md"
        with open(default_out, "w", encoding="utf-8") as fp:
            fp.write(combined_md)
        print(f"\nSaved curation summary to {default_out}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
tools/sync_city_packs.py

Synchronizes valid production City Pack releases from YatraCanvas-DataFactory
into YatraCanvas-CityPack-Lab assets directory.

ABSOLUTE RULES:
- YatraCanvas-DataFactory is READ-ONLY.
- Ignores releases/quarantine/.
- Copies only operational deployment artifacts:
  - yatracanvas.db
  - manifest.json
  - city.json
  - checksums.json
  - image_manifest.json
  - license_manifest.json
  - images/ directory
- Verifies SHA256 checksums before and after copying.
- Never copies raw parquet, jsonl, or pipeline html reports.
"""

import os
import sys
import json
import shutil
import hashlib
import argparse
from pathlib import Path

# Fix Windows console UTF-8 output
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

DEPLOYMENT_FILES = [
    "yatracanvas.db",
    "manifest.json",
    "city.json",
    "checksums.json",
    "image_manifest.json",
    "images_manifest.json",
    "license_manifest.json",
    "source_manifest.json",
]

def find_datafactory_root() -> Path:
    """Dynamically locates YatraCanvas-DataFactory relative to script or cwd."""
    candidates = [
        Path.cwd() / ".." / "YatraCanvas-DataFactory",
        Path(__file__).resolve().parent.parent.parent / "YatraCanvas-DataFactory",
        Path.home() / "Documents" / "YatraCanvas-DataFactory",
    ]
    for candidate in candidates:
        if candidate.is_dir() and (candidate / "releases").is_dir():
            return candidate.resolve()
    raise FileNotFoundError(
        "Could not find YatraCanvas-DataFactory directory. Ensure it is a sibling project."
    )

def sha256_file(filepath: Path) -> str:
    """Calculates SHA256 hash of a file."""
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(1024 * 1024):
            h.update(chunk)
    return h.hexdigest()

def discover_releases(datafactory_root: Path) -> dict:
    """Discovers all valid production releases, ignoring quarantine."""
    releases_dir = datafactory_root / "releases"
    discovered = {}

    for root, dirs, files in os.walk(releases_dir):
        root_path = Path(root)
        # Strictly ignore quarantine
        if "quarantine" in root_path.parts:
            continue

        if "manifest.json" in files and "yatracanvas.db" in files:
            try:
                with open(root_path / "manifest.json", "r", encoding="utf-8") as f:
                    manifest = json.load(f)
                city_id = manifest.get("city_id")
                city_name = manifest.get("city_name")
                if city_id:
                    discovered[city_id.lower()] = {
                        "city_id": city_id,
                        "city_name": city_name,
                        "state": manifest.get("state", ""),
                        "version": manifest.get("city_pack_version", ""),
                        "source_path": root_path,
                        "counts": manifest.get("counts", {}),
                    }
            except Exception as e:
                print(f"[WARN] Error reading manifest at {root_path}: {e}", file=sys.stderr)

    return discovered

def list_packs(datafactory_root: Path):
    """Prints all discovered packs."""
    packs = discover_releases(datafactory_root)
    print("\n" + "=" * 70)
    print("AVAILABLE PRODUCTION CITY PACKS IN DATACTORY")
    print("=" * 70)
    if not packs:
        print("No valid production city packs found.")
        return

    for cid, info in sorted(packs.items(), key=lambda x: x[1]["city_name"]):
        accepted = info["counts"].get("accepted", "N/A")
        print(f"- {info['city_name']} ({info['state']})")
        print(f"    ID:      {info['city_id']}")
        print(f"    Version: {info['version']}")
        print(f"    Places:  {accepted}")
        print(f"    Path:    {info['source_path']}\n")

def sync_packs(selected_city_ids: list, datafactory_root: Path, target_base: Path):
    """Syncs specified city packs to target directory."""
    all_packs = discover_releases(datafactory_root)
    
    # Normalize selected keys
    # Map common aliases (e.g. panaji -> panjim or vice versa)
    available_map = {}
    for cid, info in all_packs.items():
        available_map[cid] = cid
        available_map[info["city_name"].lower()] = cid
        if cid == "panaji":
            available_map["panjim"] = "panaji"
        elif cid == "panjim":
            available_map["panaji"] = "panjim"

    resolved_ids = set()
    for item in selected_city_ids:
        key = item.strip().lower()
        if key in available_map:
            resolved_ids.add(available_map[key])
        else:
            print(f"[WARN] City '{item}' not found in DataFactory releases.")

    if not resolved_ids:
        print("[ERROR] No valid cities matched for synchronization.")
        return

    target_base.mkdir(parents=True, exist_ok=True)
    summary_manifest = {}

    print(f"\n[SYNC] Synchronizing {len(resolved_ids)} city pack(s) to {target_base}...")

    for cid in sorted(resolved_ids):
        info = all_packs[cid]
        src_dir = Path(info["source_path"])
        dest_dir = target_base / cid
        dest_dir.mkdir(parents=True, exist_ok=True)

        print(f"\n---> Syncing: {info['city_name']} (v{info['version']}) [ID: {cid}]")

        # Copy deployment files
        copied_hashes = {}
        for fname in DEPLOYMENT_FILES:
            src_file = src_dir / fname
            if src_file.is_file():
                dest_file = dest_dir / fname
                src_hash = sha256_file(src_file)
                shutil.copy2(src_file, dest_file)
                dest_hash = sha256_file(dest_file)
                if src_hash != dest_hash:
                    raise RuntimeError(f"Checksum mismatch on {fname} for {cid}!")
                copied_hashes[fname] = dest_hash
                print(f"  [OK] Copied {fname} (SHA256: {dest_hash[:8]}...)")

        # Copy images directory
        src_images = src_dir / "images"
        dest_images = dest_dir / "images"
        img_count = 0
        if src_images.is_dir():
            if dest_images.exists():
                shutil.rmtree(dest_images)
            shutil.copytree(src_images, dest_images)
            for _, _, files in os.walk(dest_images):
                img_count += len(files)
            print(f"  [OK] Copied images/ ({img_count} image files)")
        else:
            print("  [INFO] No images/ folder present.")

        # Save pack local sync receipt
        receipt = {
            "city_id": cid,
            "city_name": info["city_name"],
            "state": info["state"],
            "version": info["version"],
            "source_path": str(src_dir),
            "file_checksums": copied_hashes,
            "image_count": img_count,
        }
        with open(dest_dir / "lab_sync_receipt.json", "w", encoding="utf-8") as f:
            json.dump(receipt, f, indent=2)

        summary_manifest[cid] = receipt

    # Write global packs index for Flutter
    with open(target_base / "city_packs_index.json", "w", encoding="utf-8") as f:
        json.dump(summary_manifest, f, indent=2)

    update_pubspec_assets(target_base)

    print("\n" + "=" * 70)
    print("SYNC COMPLETED SUCCESSFULLY")
    print(f"Packs synced: {list(summary_manifest.keys())}")
    print(f"Assets registered under: {target_base}")
    print("=" * 70)

def update_pubspec_assets(assets_dir: Path):
    """Updates pubspec.yaml assets section to include all city pack directories."""
    project_root = assets_dir.parent.parent
    pubspec_path = project_root / "pubspec.yaml"
    if not pubspec_path.is_file():
        return

    # Find all directories that contain files
    asset_dirs = set()
    for root, dirs, files in os.walk(assets_dir):
        if files:
            rel = Path(root).relative_to(project_root).as_posix()
            asset_dirs.add(f"    - {rel}/")

    # Add base files/dirs
    asset_dirs.add("    - assets/city_packs/")
    asset_dirs.add("    - assets/city_packs/city_packs_index.json")

    sorted_entries = sorted(list(asset_dirs))

    with open(pubspec_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Locate flutter: section
    if "  assets:" in content:
        # Replace existing assets section
        parts = content.split("  assets:")
        pre = parts[0]
        rest = parts[1]
        # Find end of assets block (next non-indented or 2-space line)
        lines = rest.splitlines()
        remaining_lines = []
        in_assets = True
        for line in lines:
            if in_assets:
                if line.startswith("    - ") or line.strip() == "" or line.startswith("    #"):
                    continue
                else:
                    in_assets = False
                    remaining_lines.append(line)
            else:
                remaining_lines.append(line)

        new_assets_block = "  assets:\n" + "\n".join(sorted_entries) + "\n"
        new_content = pre + new_assets_block + "\n".join(remaining_lines)
    else:
        # Add assets: under flutter:
        if "flutter:" in content:
            replacement = "flutter:\n  uses-material-design: true\n  assets:\n" + "\n".join(sorted_entries) + "\n"
            new_content = content.replace("flutter:\n\n  # The following line ensures that the Material Icons font is\n  # included with your application, so that you can use the icons in\n  # the material Icons class.\n  uses-material-design: true", replacement)
            if new_content == content:
                # Fallback simple replacement
                new_content = content.replace("flutter:", "flutter:\n  assets:\n" + "\n".join(sorted_entries))
        else:
            new_content = content

    with open(pubspec_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print(f"  [OK] Updated pubspec.yaml with {len(sorted_entries)} asset paths.")

def main():
    parser = argparse.ArgumentParser(description="Sync City Packs from YatraCanvas-DataFactory to CityPack-Lab")
    parser.add_argument("--list", action="store_true", help="List available production packs in DataFactory")
    parser.add_argument("--cities", type=str, help="Comma-separated city IDs or names (e.g. 'Manali,Rishikesh,Panaji,Gulmarg')")
    parser.add_argument("--all", action="store_true", help="Sync all available production packs")
    parser.add_argument("--target", type=str, default="assets/city_packs", help="Target assets directory")
    args = parser.parse_args()

    datafactory_root = find_datafactory_root()
    print(f"[INFO] Discovered YatraCanvas-DataFactory at: {datafactory_root}")

    if args.list:
        list_packs(datafactory_root)
        return

    target_base = Path(args.target).resolve()
    if args.all:
        all_packs = discover_releases(datafactory_root)
        sync_packs(list(all_packs.keys()), datafactory_root, target_base)
    elif args.cities:
        city_list = [c.strip() for c in args.cities.split(",") if c.strip()]
        sync_packs(city_list, datafactory_root, target_base)
    else:
        # Default testing profile
        default_cities = ["manali", "rishikesh", "panaji", "gulmarg"]
        print("[INFO] No arguments specified. Using default testing profile: Manali, Rishikesh, Panaji, Gulmarg")
        sync_packs(default_cities, datafactory_root, target_base)

if __name__ == "__main__":
    main()

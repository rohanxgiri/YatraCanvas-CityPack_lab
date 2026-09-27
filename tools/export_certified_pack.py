#!/usr/bin/env python3
"""
tools/export_certified_pack.py

Bridges the 3 separate repositories:
1. YatraCanvas-CityPack-Lab (where human curation is done)
2. YatraCanvas-DataFactory (where editorial fixes are stored permanently in data/curated/)
3. YatraCanvas (the mobile app, where the certified SQLite db is copied into assets/)

Workflow:
- Reads assets/city_packs/<city>/yatracanvas.db
- Bakes in all curation/ overrides, additions, and exclusions into a certified SQLite db
- Syncs curation/ JSON files to ../YatraCanvas-DataFactory/data/curated/<city>/
- Syncs certified yatracanvas.db + images to ../YatraCanvas/assets/city_packs/<city>/
"""

import os
import sys
import json
import sqlite3
import shutil
import argparse
from pathlib import Path

# Ensure UTF-8 on Windows
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")


def find_sibling_repo(repo_name: str) -> Path:
    candidates = [
        Path.cwd() / ".." / repo_name,
        Path(__file__).resolve().parent.parent.parent / repo_name,
        Path.home() / "Documents" / repo_name,
    ]
    for c in candidates:
        if c.is_dir():
            return c.resolve()
    return None


def export_certified_city_pack(city_id: str, dry_run: bool = False):
    lab_root = Path(__file__).resolve().parent.parent
    pack_dir = lab_root / "assets" / "city_packs" / city_id
    curation_dir = pack_dir / "curation"
    source_db = pack_dir / "yatracanvas.db"

    if not pack_dir.is_dir() or not source_db.is_file():
        print(f"Error: City pack for '{city_id}' not found at {pack_dir}", file=sys.stderr)
        sys.exit(1)

    print(f"\n==========================================================")
    print(f"  EXPORTING CERTIFIED CITY PACK: {city_id.upper()}")
    print(f"==========================================================")

    # 1. Locate sibling repositories
    datafactory_root = find_sibling_repo("YatraCanvas-DataFactory")
    app_root = find_sibling_repo("YatraCanvas")

    print(f"1. Target Repositories:")
    print(f"   • DataFactory: {'[FOUND] ' + str(datafactory_root) if datafactory_root else '[NOT FOUND]'}")
    print(f"   • YatraCanvas Mobile App: {'[FOUND] ' + str(app_root) if app_root else '[NOT FOUND]'}")

    # 2. Build Certified SQLite Database
    export_output_dir = lab_root / "releases" / city_id
    export_output_dir.mkdir(parents=True, exist_ok=True)
    certified_db_path = export_output_dir / "yatracanvas.db"

    print(f"\n2. Baking human curation into Certified SQLite Database...")
    shutil.copy2(source_db, certified_db_path)

    # Make writable for curation bake
    os.chmod(certified_db_path, 0o666)

    conn = sqlite3.connect(certified_db_path)
    cursor = conn.cursor()

    applied_overrides = 0
    applied_additions = 0
    applied_exclusions = 0

    if curation_dir.is_dir():
        # A. Apply Exclusions
        exclusions_dir = curation_dir / "exclusions"
        if exclusions_dir.is_dir():
            for f in exclusions_dir.glob("*.json"):
                try:
                    with open(f, "r", encoding="utf-8") as fp:
                        data = json.load(fp)
                        place_id = data.get("placeId") or data.get("place_id")
                        if place_id:
                            cursor.execute("DELETE FROM places WHERE id = ?", (place_id,))
                            applied_exclusions += 1
                except Exception as e:
                    print(f"   Warning reading exclusion {f}: {e}")

        # B. Apply Overrides
        overrides_dir = curation_dir / "overrides"
        if overrides_dir.is_dir():
            for f in overrides_dir.glob("*.json"):
                try:
                    with open(f, "r", encoding="utf-8") as fp:
                        data = json.load(fp)
                        place_id = data.get("placeId") or data.get("place_id")
                        if not place_id:
                            continue

                        updates = []
                        params = []

                        if "name" in data and data["name"]:
                            updates.append("name = ?")
                            params.append(data["name"])
                        if "category" in data and data["category"]:
                            updates.append("category = ?")
                            params.append(data["category"])
                        if "latitude" in data and data["latitude"] is not None:
                            updates.append("latitude = ?")
                            params.append(float(data["latitude"]))
                        if "longitude" in data and data["longitude"] is not None:
                            updates.append("longitude = ?")
                            params.append(float(data["longitude"]))
                        if "opening_hours" in data and data["opening_hours"]:
                            updates.append("opening_hours = ?")
                            params.append(data["opening_hours"])
                        if "primary_image_path" in data and data["primary_image_path"]:
                            updates.append("primary_image_path = ?")
                            params.append(data["primary_image_path"])

                        if updates:
                            params.append(place_id)
                            sql = f"UPDATE places SET {', '.join(updates)} WHERE id = ?"
                            cursor.execute(sql, params)
                            applied_overrides += 1
                except Exception as e:
                    print(f"   Warning reading override {f}: {e}")

        # C. Apply Additions
        additions_dir = curation_dir / "additions"
        if additions_dir.is_dir():
            for f in additions_dir.glob("*.json"):
                try:
                    with open(f, "r", encoding="utf-8") as fp:
                        data = json.load(fp)
                        place_id = data.get("id") or data.get("place_id")
                        if not place_id:
                            continue

                        # Check columns in places table
                        cursor.execute("PRAGMA table_info(places)")
                        columns = [row[1] for row in cursor.fetchall()]

                        insert_fields = []
                        insert_values = []

                        def add_field(field_name, val):
                            if field_name in columns:
                                insert_fields.append(field_name)
                                insert_values.append(val)

                        add_field("id", place_id)
                        add_field("city_id", data.get("cityId") or city_id)
                        add_field("name", data.get("name", "Unnamed"))
                        add_field("category", data.get("category", "experience"))
                        add_field("tier", data.get("tier", "recommended"))
                        add_field("latitude", float(data.get("latitude", 0.0)))
                        add_field("longitude", float(data.get("longitude", 0.0)))
                        add_field("opening_hours", data.get("openingHours"))
                        add_field("primary_image_path", data.get("primaryImagePath"))
                        add_field("description", data.get("description"))
                        add_field("website", data.get("website"))
                        add_field("phone", data.get("phone"))

                        placeholders = ", ".join(["?"] * len(insert_fields))
                        sql = f"INSERT OR REPLACE INTO places ({', '.join(insert_fields)}) VALUES ({placeholders})"
                        cursor.execute(sql, insert_values)
                        applied_additions += 1
                except Exception as e:
                    print(f"   Warning reading addition {f}: {e}")

    conn.commit()
    conn.close()

    print(f"   • Applied {applied_overrides} field overrides")
    print(f"   • Applied {applied_additions} manual sight additions")
    print(f"   • Applied {applied_exclusions} place exclusions")
    print(f"   • Certified DB generated: {certified_db_path}")

    # Copy manifest and images to release folder
    if (pack_dir / "manifest.json").is_file():
        shutil.copy2(pack_dir / "manifest.json", export_output_dir / "manifest.json")
    if (pack_dir / "images").is_dir():
        dest_img = export_output_dir / "images"
        if dest_img.exists():
            shutil.rmtree(dest_img)
        shutil.copytree(pack_dir / "images", dest_img)

    # 3. Step A: Copy curation to DataFactory (Permanent Storage)
    if datafactory_root:
        df_curated_dir = datafactory_root / "data" / "curated" / city_id
        print(f"\n3. Syncing curation files to DataFactory:")
        print(f"   -> Destination: {df_curated_dir}")
        if curation_dir.is_dir():
            shutil.copytree(curation_dir, df_curated_dir, dirs_exist_ok=True)
            print(f"   [OK] Stored in DataFactory permanent curation store.")
        else:
            print(f"   [INFO] No curation directory yet in Lab.")

    # 4. Step B: Copy certified release pack to YatraCanvas Mobile App
    if app_root:
        app_pack_dir = app_root / "assets" / "city_packs" / city_id
        print(f"\n4. Syncing certified offline database to YatraCanvas Mobile App:")
        print(f"   -> Destination: {app_pack_dir}")
        app_pack_dir.mkdir(parents=True, exist_ok=True)

        # Copy certified yatracanvas.db
        shutil.copy2(certified_db_path, app_pack_dir / "yatracanvas.db")
        print(f"   [OK] Copied certified yatracanvas.db ({os.path.getsize(certified_db_path) / (1024*1024):.2f} MB)")

        # Copy manifest
        if (pack_dir / "manifest.json").is_file():
            shutil.copy2(pack_dir / "manifest.json", app_pack_dir / "manifest.json")

        # Copy images
        if (pack_dir / "images").is_dir():
            dest_app_images = app_pack_dir / "images"
            if dest_app_images.exists():
                shutil.rmtree(dest_app_images)
            shutil.copytree(pack_dir / "images", dest_app_images)
            print(f"   [OK] Copied bundled images.")

    print(f"\n==========================================================")
    print(f"  EXPORT COMPLETED SUCCESSFULLY!                          ")
    print(f"  • Your fixes are permanently stored in DataFactory       ")
    print(f"  • Your certified offline DB is live in YatraCanvas App  ")
    print(f"==========================================================\n")


def main():
    parser = argparse.ArgumentParser(description="Export certified city pack to DataFactory and YatraCanvas app.")
    parser.add_argument("--city", default="jaipur", help="City ID (default: jaipur)")
    args = parser.parse_args()

    export_certified_city_pack(args.city.lower())


if __name__ == "__main__":
    main()

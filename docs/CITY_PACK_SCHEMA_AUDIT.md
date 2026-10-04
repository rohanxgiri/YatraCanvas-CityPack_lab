# City Pack Schema Audit

## Overview

This audit document details the concrete, inspected schema of the DataFactory City Pack release artifacts located in `YatraCanvas-DataFactory/releases/india/*/v3`.

## 1. Release Files

Each valid production release contains:

| File | Purpose | Deployment Artifact? |
|------|---------|----------------------|
| `yatracanvas.db` | Primary SQLite database containing places, cities, tags, images, sources | **YES** |
| `manifest.json` | Top-level metadata, counts, tier distribution, checksums, pipeline health | **YES** |
| `city.json` | Canonical city metadata, center coordinates, bounding box, alternate names | **YES** |
| `checksums.json` | Cryptographic SHA256 checksums for each release file | **YES** |
| `image_manifest.json` | Detailed per-place image licenses, sources, authors, and matching methods | **YES** |
| `license_manifest.json` | Legal attributions and open-data license declarations (ODbL, CC-BY-SA, etc.) | **YES** |
| `images/` | Directory of local WebP images: `<place_id>/primary.webp` and `<place_id>/thumbnail.webp` | **YES** |
| `places.parquet` | Pipeline columnar format for batch analytics | No (Pipeline only) |
| `places.json` | Full JSON export of places | No (Redundant with SQLite) |
| `places.jsonl` | Line-delimited JSON export | No (Redundant with SQLite) |
| `quality_report.html` | HTML summary of automated pipeline quality checks | No (QA documentation only) |

## 2. SQLite Database Schema (`yatracanvas.db`)

### Table: `cities`

| Column | Type | Nullable | Primary Key | Description |
|---|---|---|---|---|
| `id` | TEXT | No | Yes | Canonical city identifier (e.g. `manali`, `panaji`) |
| `name` | TEXT | No | No | City display name (e.g. `Manali`) |
| `state` | TEXT | No | No | State (e.g. `Himachal Pradesh`) |
| `country` | TEXT | No | No | Country (`India`) |
| `center_lat` | REAL | No | No | Latitude of city centroid |
| `center_lon` | REAL | No | No | Longitude of city centroid |
| `min_lon` | REAL | No | No | Bounding box minimum longitude |
| `min_lat` | REAL | No | No | Bounding box minimum latitude |
| `max_lon` | REAL | No | No | Bounding box maximum longitude |
| `max_lat` | REAL | No | No | Bounding box maximum latitude |
| `timezone` | TEXT | No | No | IANA timezone (e.g. `Asia/Kolkata`) |

### Table: `places`

| Column | Type | Nullable | Default | Description |
|---|---|---|---|---|
| `id` | TEXT | No | None | Unique place ID (e.g. `yc_in_hp_manali_manali`) |
| `city_id` | TEXT | No | None | Foreign key referencing `cities(id)` |
| `name` | TEXT | No | None | Canonical English name |
| `name_hi` | TEXT | Yes | None | Local Hindi name |
| `latitude` | REAL | No | None | WGS84 Latitude |
| `longitude` | REAL | No | None | WGS84 Longitude |
| `address` | TEXT | Yes | None | Street / postal address |
| `category` | TEXT | No | None | Primary category (e.g. `heritage`, `food`, `nature`, `religious`, `shopping`, `culture`, `hospitality`, `transit`) |
| `subcategory` | TEXT | Yes | None | Specific subcategory (e.g. `attraction`, `temple`, `waterfall`, `cafe`) |
| `primary_entity_type` | TEXT | Yes | None | Ontological entity classification (e.g. `historic_site`, `hindu_temple`) |
| `tier` | TEXT | No | `'discovery'` | Hierarchy tier: `core_destination`, `recommended`, `discovery`, `support` |
| `travel_relevance_score` | REAL | Yes | `0.0` | Algorithmic tourist relevance score (0.0 to 1.0) |
| `prominence_score` | REAL | Yes | `0.0` | Global prominence / popularity score (0.0 to 1.0) |
| `recommended_visit_minutes` | INTEGER | Yes | None | Suggested visit duration in minutes |
| `tourism_priority` | REAL | Yes | None | Composite sorting priority |
| `family_friendly` | INTEGER | Yes | None | 1 = family friendly, 0 = no / unverified |
| `best_time` | TEXT | Yes | None | Recommended time of day (e.g. `morning`, `evening`) |
| `website` | TEXT | Yes | None | Official website URL |
| `phone` | TEXT | Yes | None | Phone number |
| `opening_hours` | TEXT | Yes | None | Formatted opening hours string |
| `overture_id` | TEXT | Yes | None | Overture Maps ID |
| `osm_id` | TEXT | Yes | None | OpenStreetMap ID (`node/...`, `way/...`) |
| `wikidata_id` | TEXT | Yes | None | Wikidata entity identifier (e.g. `Q83443`) |
| `foursquare_id` | TEXT | Yes | None | Foursquare venue ID |
| `wikivoyage_listing_id` | TEXT | Yes | None | Wikivoyage listing ID |
| `quality_overall` | REAL | Yes | None | Synthesized data quality score (0.0 to 1.0) |
| `anomaly_score` | REAL | Yes | `0.0` | Anomaly / risk score |
| `primary_image_path` | TEXT | Yes | None | Relative path (e.g. `images/<id>/primary.webp`) |
| `thumbnail_image_path` | TEXT | Yes | None | Relative path (e.g. `images/<id>/thumbnail.webp`) |
| `generated_at` | TEXT | Yes | None | ISO8601 generation timestamp |

### Table: `place_tags`

| Column | Type | Nullable | Primary Key | Description |
|---|---|---|---|---|
| `place_id` | TEXT | No | Part 1 | References `places(id)` |
| `tag` | TEXT | No | Part 2 | Tag descriptor (e.g. `architecture`, `scenic`, `viewpoint`) |

### Table: `place_images`

| Column | Type | Nullable | Primary Key | Description |
|---|---|---|---|---|
| `id` | INTEGER | No | Yes | Auto-increment ID |
| `place_id` | TEXT | No | No | References `places(id)` |
| `original_file` | TEXT | No | No | Original Wikimedia / source filename |
| `local_path` | TEXT | No | No | Local relative path (e.g. `images/.../primary.webp`) |
| `thumbnail_path` | TEXT | Yes | No | Local thumbnail path |
| `author` | TEXT | Yes | No | Photographer / creator attribution |
| `license` | TEXT | No | No | SPDX license string (e.g. `CC BY-SA 4.0`) |
| `license_url` | TEXT | Yes | No | URL to license deed |
| `attribution` | TEXT | Yes | No | Specific attribution statement |
| `match_method` | TEXT | Yes | No | How image was matched (e.g. `wikidata_p18`, `commons_category_gallery`) |
| `match_confidence` | REAL | Yes | None | Algorithmic confidence score |

### Table: `place_sources`

| Column | Type | Nullable | Primary Key | Description |
|---|---|---|---|---|
| `id` | INTEGER | No | Yes | Auto-increment ID |
| `place_id` | TEXT | No | No | References `places(id)` |
| `source` | TEXT | No | No | Upstream source name (`wikidata`, `openstreetmap`, `overture`, `wikivoyage`) |
| `source_id` | TEXT | Yes | No | Identifier in upstream dataset |
| `retrieved_at` | TEXT | Yes | No | Retrieval timestamp |

## 3. Existing SQLite Indexes

The DataFactory database already provisions the following indexes:
- `idx_places_city_id` on `places(city_id)`
- `idx_places_category` on `places(category)`
- `idx_places_tier` on `places(tier)`
- `idx_places_relevance` on `places(travel_relevance_score DESC)`
- `idx_places_coords` on `places(latitude, longitude)`
- `idx_places_priority` on `places(tourism_priority DESC)`
- `idx_place_tags_tag` on `place_tags(tag)`

## 4. Search Implementation Strategy for QA Lab

DataFactory does not include an FTS5 virtual table in `yatracanvas.db`. However, `places` contains:
- `name`
- `name_hi`
- `category`
- `subcategory`
- `primary_entity_type`
- `address`
and associated `place_tags(tag)`.

In the Lab, SQLite query performance is fast because:
1. Category queries use the existing index `idx_places_category`.
2. Tier queries use `idx_places_tier`.
3. Deterministic natural text search queries filter by:
   `WHERE name LIKE ? OR name_hi LIKE ? OR category LIKE ? OR subcategory LIKE ? OR primary_entity_type LIKE ? OR id IN (SELECT place_id FROM place_tags WHERE tag LIKE ?)`
   ordering by `tourism_priority DESC, travel_relevance_score DESC`.
4. All queries use `LIMIT` and `OFFSET` pagination, never buffering all records in Dart memory.

## 5. Image Directory Structure

Images are stored strictly as:
```
images/
  <place_id>/
    primary.webp
    thumbnail.webp
```
Missing images are represented as null/empty `primary_image_path` in SQLite and absence of directory on disk.
In the Lab, any missing image will render a dedicated, clear **"No local image"** placeholder.


## Bundled city-data loop — 2026-10-04

`[IMPLEMENTED]` See [the city-data loop](CITY_DATA_DEV_LOOP.md) for the new immutable app export, base-bound human repair patch and safe sync commands. Existing strict certification/provider architecture remains intact. `[PARTIAL]` Physical-phone acceptance remains unverified. No production migration or paid provider call is part of this loop.

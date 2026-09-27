# YatraCanvas CityPack Lab

**Real-Flow Manual Dataset QA Application**

A dedicated Flutter application built to realistically test and audit city-pack datasets produced by `YatraCanvas-DataFactory` before they are integrated into the main YatraCanvas mobile application.

---

## The Core Question

> *"If a real traveller used these City Packs inside YatraCanvas, would the data actually feel useful, relevant, and trustworthy?"*

Automated pipeline tests check schema compliance, coordinates geometry, classification heuristics, and basic coverage. **This Lab tests human product flow**:
- Browsing Core, Recommended, and Discovery tiers
- Natural offline searches (e.g. `cafe`, `waterfall`, `viewpoint`, `fort`)
- Inspecting local imagery vs missing-image conditions
- Visualizing spatial distribution on geographic maps
- Creating multi-day test trips and evaluating geographic clustering
- Reviewing deterministic random samples of places
- Checking landmark recall (Expected Places)
- Logging defect reports without modifying production database releases

---

## Absolute Rules & Constraints

1. **Read-Only Input**: DataFactory release artifacts are strictly immutable inputs.
2. **Zero Remote POIs**: No Geoapify, Google Places, Foursquare, Overpass, or backend APIs.
3. **Local Media Only**: Images come exclusively from the City Pack. Missing images display a neutral `"No local image"` placeholder.
4. **Separate QA Storage**: QA annotations and defect tickets are saved to `ApplicationDocuments/qa_sessions/`, never into `yatracanvas.db`.
5. **Strict Offline Mode**: Toggleable mode that cuts even visual OSM tiles, proving 100% offline data integrity.

---

## Quick Start Guide

### 1. Prerequisites
- Flutter 3.47.0+ (stable channel)
- Python 3.10+ (for pack synchronizer)

### 2. Synchronize City Packs from DataFactory
```bash
# List available production releases
python tools/sync_city_packs.py --list

# Sync default testing profile (Manali, Rishikesh, Panaji, Gulmarg)
python tools/sync_city_packs.py --cities "Manali,Rishikesh,Panaji,Gulmarg"

# Or sync all production releases
python tools/sync_city_packs.py --all
```

### 3. Run the Application
```bash
# Get dependencies
flutter pub get

# Run on connected device (Android emulator / Desktop)
flutter run
```

### 4. Run Automated Quality Tests
```bash
# Analyze codebase
flutter analyze

# Run unit, repository, and widget integration tests
flutter test
```

---

## Synchronized Testing Packs (Default Profile)

| City | State | Places | DB Size | Image Files | Status |
|---|---|---|---|---|---|
| **Gulmarg** | Jammu & Kashmir | 84 | 0.18 MB | 20 images (2.47 MB) | `PASS` |
| **Rishikesh** | Uttarakhand | 1,409 | 2.00 MB | 30 images (2.99 MB) | `PASS` |
| **Manali** | Himachal Pradesh | 1,702 | 2.13 MB | 24 images (2.77 MB) | `PASS` |
| **Panaji** | Goa | 3,753 | 4.98 MB | 106 images (9.17 MB) | `PASS` |

*Stress testing with **Jaipur** (10,060 places, 13.39 MB DB) is supported via `python tools/sync_city_packs.py --cities "Jaipur"`.*

---

## Application Screen Matrix

1. **City Pack Selection Screen**: Displays available packs, place/image counts, DB sizes, and SHA256 integrity status badges.
2. **Interest Selection Screen**: Select travel themes derived dynamically from the dataset categories.
3. **Discover Places Feed**: Multi-section feed (Top Destinations, Recommended, Interests, Discovery, Food & Cafes) with tier filters.
4. **Natural Search Screen**: Deterministic SQLite search across names, categories, and tags. Includes **Search Result Review Mode** for rating relevance (Relevant / Partial / Irrelevant / Unsure).
5. **Category Browser**: Browse all dataset categories with sorting by priority, name, tier, or relevance, plus a toggle to expose hidden long-tail records.
6. **Place Details & QA Inspector**: Normal traveler view alongside full **QA Mode** exposing internal DataFactory scores (`travel_relevance`, `anomaly_score`), upstream IDs (Wikidata, OSM, Overture), source attribution, and image licenses.
7. **Geographic Map Inspection**: Interactive map markers with tier color-coding and full support for **Strict Offline Mode** (coordinate canvas without tile downloads).
8. **Random Review Mode**: Deterministic seeded random sampling (20–100 places) for rapid 1-by-1 evaluation with 9 defect buttons and note logging.
9. **Expected Places Check**: Search and mark whether expected city landmarks are `FOUND`, `DATA WRONG`, or `NOT FOUND`.
10. **Test Trip Basket & Trip Map**: Multi-day trip basket (1–7 days) with geographic coordinate clustering.
11. **Realistic Scenario Testing**: Guided walkthrough for evaluating dataset usability with final trust rating (`YES`, `MOSTLY`, `NO`).
12. **QA Dashboard & Export**: City dataset metrics, issue breakdowns, and one-click export to machine-readable JSON (`qa_<city>_<date>.json`) and Markdown summaries (`qa_<city>_<date>.md`).
13. **Network Transparency & Diagnostics**: Live proof of zero remote POI calls, zero backend requests, and SQLite latency measurements.

---

## Documentation Links

- [25–30 Minute Dataset QA Protocol](docs/DATASET_QA_GUIDE.md)
- [System Architecture](docs/LAB_ARCHITECTURE.md)
- [City Pack Schema Audit](docs/CITY_PACK_SCHEMA_AUDIT.md)
- [City Pack Size & Capacity Report](docs/CITY_PACK_SIZE_REPORT.md)
- [Lab Environment Report](docs/LAB_ENVIRONMENT.md)

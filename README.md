# YatraCanvas CityPack Lab

**Data Quality, Travel Readiness & Production Release Gate System**

A dedicated Flutter application built to audit, stress-test, and certify city-pack datasets produced by `YatraCanvas-DataFactory` before they are integrated into the main YatraCanvas travel mobile app.

---

## The Core Mission

Automated pipeline heuristics check schema compliance, geometries, and basic field presence. **CityPack Lab acts as the definitive production gatekeeper**, answering at a single glance:

1. **What data has DataFactory actually generated?** (Places, tiers, categories, tags, images, source provenance)
2. **How complete and trustworthy is the data?** (Weighted 8-dimension Data Quality score)
3. **What is missing?** (Category gaps, core landmark images, operating schedules)
4. **What records are suspicious?** (Geographic outliers, low provenance, high anomaly scores)
5. **What needs human review?** (Stratified 50-place QA queue across high-impact tiers)
6. **Is the dataset actually useful for YatraCanvas itinerary generation?** (5-dimension Travel Readiness score)
7. **Can this City Pack safely be integrated into YatraCanvas?** (`READY`, `REVIEW_REQUIRED`, `BLOCKED`)
8. **If blocked, what exact critical blockers are preventing release?**
9. **What does DataFactory need to improve?** (Actionable gaps and pipeline defect reports)

---

## Architectural Principles & Non-Negotiables

1. **Read-Only Input**: Shipped database releases (`yatracanvas.db`) are strictly immutable. The app opens databases in read-only mode and never mutates production data.
2. **Zero Remote POI Calls**: No external requests to Google Places, Geoapify, Foursquare, Overpass, or YatraCanvas backend APIs. Quality is measured purely on what is bundled.
3. **No Fabricated Quality**: Zero manual reviews = `NOT STARTED` / `PENDING` (never 100%). Quality scores reflect unverified state rather than granting free perfection.
4. **Critical Gates Override Averages**: A 95% overall score **cannot override** a critical blocker (e.g. 0/50 manual reviews completed, Core landmarks outside city bounds, or missing hero images on top attractions).
5. **Candidate Rejection Is Not City Quality**: Pipeline rejection statistics belong strictly under **Pipeline Diagnostics** and do not artificially depress or inflate the quality of certified places in `yatracanvas.db`.
6. **Two Independent Scores**:
   - **Data Quality Score (0–100)**: Cleanliness, completeness, coordinates, provenance, and deduplication.
   - **Travel Readiness Score (0–100)**: Anchor attraction depth, category balance, hero media availability, schedule coverage, and itinerary viability.

---

## The 5 Operational Pillars

The application is structured into 5 simple, actionable screens designed for contributors and release managers:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                  YATRACANVAS CITY PACK CURATION STUDIO                      │
├───────────────┬─────────────────┬──────────────┬──────────────┬─────────────┤
│ 1. Home       │ 2. Fix Center   │ 3. Review    │ 4. Places    │ 5. Release  │
│ (10s Scan)    │ (Task Runner)   │ (Manual QA)  │ (Edit & CMS) │ (Gate & Cert│
└───────────────┴─────────────────┴──────────────┴──────────────┴─────────────┘
```

### 1. Home & Executive Health (`HomeScreen`)
- **10-Second Executive Scan**: Large circular City Health score gauge (0–100) with instant health status.
- **4 Actionable Task Cards**: Instant counts for missing photos, missing opening hours, coordinate errors, and category issues with 1-click jump into the Fix Center.
- **Manual Verification Status**: Real-time progress bar tracking the 50-place manual QA sample requirement (`NOT STARTED`, `IN PROGRESS X/50`, or `PASSED`).
- **Primary Hero Action**: Direct button to "Start Fixing" or "Continue Reviewing" without browsing complicated technical menus.

### 2. Fix Center (`FixCenterScreen`)
- **Task-Driven Work Runner**: Turns abstract coverage metrics into clear, step-by-step fix queues.
- **Actionable Work Categories**:
  - Missing Opening Hours (Quick presets, weekday sync, official sources)
  - Missing & Broken Images (Photo inspector, media assignment, attribution)
  - Coordinate & Boundary Problems (Lat/Lon corrections, boundary checking)
  - Category Corrections (YatraCanvas 14-category taxonomy)
  - Collaborative Issues (Open, assigned, and verified tickets)
- **Automatic Score Recalculation**: Saving any fix instantly recalculates the City Health and Travel Readiness scores in-memory.

### 3. Review Queue (`CurationReviewScreen`)
- **Streamlined Verification**: A clean, focused single-card QA queue without overwhelming data dumps.
- **Smart Sampling**: Automatically queues 50 representative places across Core destinations, discovery sights, and edge cases.
- **Zero-Loop Guarantee**: Places already reviewed are automatically excluded from future review queues.
- **1-Click Actions**: Approve (`Yes, Looks Good`) or Flag with defects (`Wrong Photo`, `Wrong Category`, `Closed`, `Wrong Location`).

### 4. Places CMS & Place Detail (`PlacesCmsScreen` & `CuratedPlaceDetailScreen`)
- **Lightweight Inventory CMS**: Search places instantly (<25ms across 10k rows), filter by category, tier, or issue flags.
- **+ Add Place Wizard**: 5-step wizard to add missing landmarks, temples, or stepwells with verified coordinates and hours.
- **Safe Place Exclusions**: Soft-delete permanently closed or inappropriate places with mandatory reason logging (never destroys raw source data).
- **Field-Level Provenance & Audit History**: View exact sources for every field (e.g. OSM vs. Verified Human Override) and view change logs.

### 5. Release Gate Certification (`ReleaseGateScreen`)
- **7 Non-Negotiable Hard Gates**: Tests schema integrity, boundary containment, manual QA completion, flagship photo depth, cultural sights count, and composite thresholds.
- **Blocker Overrides**: High average scores can never bypass a critical blocker (e.g. Core places out of bounds strictly blocks release).
- **Certified Artifact Export**: 1-click generation of `release.json`, `quality_report.json`, and `release_report.md`.

*(Note: Advanced DataFactory diagnostics, raw candidate funnels, and category coverage matrices are safely accessible under the **Advanced** tab in Admin Mode).*

---

## Real Dataset Audit Benchmark (Jaipur v3)

Auditing the real `yatracanvas.db` for Jaipur (10,060 places, v3 release) yields the following ground truth:

| Metric | Result | Status | Note |
|---|:---:|:---:|---|
| **Total Places** | 10,060 | — | 80 Core, 484 Recommended, 9,496 Discovery |
| **Local Images** | 47 / 80 Core (58.8%) | ⚠️ GAP | 33 Core places missing photos |
| **Opening Hours** | 17 / 80 Core (21.3%) | ⚠️ GAP | 63 Core places missing hours |
| **Data Quality Score** | **65 / 100** | ❌ BLOCKED | Below 70 threshold (dragged down by Core image & hours gaps) |
| **Travel Readiness Score** | **80 / 100** | ✅ READY | Rich heritage and diverse category depth |
| **Manual QA Status** | `NOT STARTED (0/50)` | ❌ BLOCKED | Sample must reach 50 before release |
| **Release Gate Status** | **`BLOCKED`** | ❌ BLOCKED | 2 Critical Blockers: 0/50 reviews, DQ score 65 < 70 |

*Simulating 50 verified manual reviews elevates Data Quality to 67, keeping release safely BLOCKED until DataFactory enriches Core photos and hours.*

---

## Quick Start & Running

### 1. Prerequisites
- Flutter 3.47.0+ (stable channel)
- Chrome (for web testing) or Android / Windows Desktop environment
- Python 3.10+ (for pack synchronizer)

### 2. Synchronize City Packs from DataFactory
```bash
# List available production releases in DataFactory
python tools/sync_city_packs.py --list

# Sync default testing profile (Manali, Rishikesh, Panaji, Gulmarg)
python tools/sync_city_packs.py --cities "Manali,Rishikesh,Panaji,Gulmarg"

# Or sync stress-test pack (Jaipur: 10,060 places)
python tools/sync_city_packs.py --cities "Jaipur"
```

### 3. Run the Application

#### In Chrome / Web (WASM Supported via `sqflite_common_ffi_web`):
```bash
flutter run -d chrome
```

#### On Windows Desktop or Connected Mobile Device:
```bash
flutter run
```

### 4. Run Automated Test Suites
```bash
# Run all unit, engine, and integration tests
flutter test

# Run the Quality & Release Gate engine tests (6 test cases A–F)
flutter test test/quality_engine_test.dart

# Run evaluation on real Jaipur production database
flutter test test/jaipur_quality_eval_test.dart

# Static analysis (zero warnings / errors)
flutter analyze
```

---

## Project Structure

```
lib/
├── app/
│   ├── app_state.dart              # Global reactive state & dynamic quality recalculation
│   └── routes.dart                 # Application navigation routes
├── curation/
│   ├── curation_repository.dart    # Entity-level JSON store (overrides, additions, exclusions)
│   └── curation_service.dart       # Overlay resolution & live dynamic stats recomputation
├── data/
│   ├── city_pack_database.dart     # SQLite reader, aggregates & coverage matrices
│   ├── city_pack_loader.dart       # Copies & loads bundled SQLite packs
│   └── local_place_repository.dart # Place repository contract & implementation
├── domain/
│   ├── city.dart                   # City entity & bounding box
│   ├── lab_place.dart              # Place model with convenience getters
│   └── curation/                   # Curated place models with field-level provenance
│       ├── curated_place.dart      # CuratedPlace = (Raw + Additions - Exclusions) ⊕ Overrides
│       ├── curation_issue.dart     # Issue lifecycle (open, assigned, fixed, verified)
│       ├── place_addition.dart     # Scout addition model [MANUAL ADDITION]
│       ├── place_exclusion.dart    # Safe tombstone model with mandatory reasons
│       ├── place_override.dart     # Field override model with audit history
│       └── place_review.dart       # Manual QA review model
├── quality/
│   ├── config/                     # Weights & release gate thresholds
│   ├── models/                     # Quality scores, dimensions & QA models
│   └── services/                   # 8 DQ dimensions, 5 TR dimensions, 7 hard gates
├── screens/
│   ├── city_lab_home_screen.dart   # Top navigation shell with Contributor/Admin mode toggle
│   ├── home_screen.dart            # Pillar 1: 10-second executive scan & Health Score
│   ├── fix_center_screen.dart      # Pillar 2: Task-oriented fix runners
│   ├── curation_review_screen.dart # Pillar 3: Streamlined QA verification queue
│   ├── places_cms_screen.dart      # Pillar 4: Curated place inventory CMS & + Add Place
│   ├── curated_place_detail_screen.dart # Field provenance & audit history
│   └── release_gate_screen.dart    # Pillar 5: 7-Gate checklist & certified export
└── widgets/
    ├── score_ring.dart             # CustomPainter circular score gauge
    └── curation/                   # Dialog editors (hours, images, coords, categories, etc.)
```

---

## The 3-Repository Ecosystem & Bridge

The YatraCanvas travel platform is split across 3 sibling repositories in `C:\Users\girir\Documents\`:

| Repository | Role | Technology |
|---|---|---|
| **`YatraCanvas-DataFactory`** | Automated harvesting, normalization & candidate clustering | Python |
| **`YatraCanvas-CityPack-Lab`** | Human curation, verification, release gate certification | Flutter |
| **`YatraCanvas`** | Consumer travel mobile application | Flutter Mobile |

### The Bridge Commands

```powershell
# 1. Setup environment and dependencies
.\citylab.ps1 setup

# 2. Pull latest raw pack from DataFactory into City Lab:
python tools/sync_city_packs.py --cities Jaipur

# 3. Launch Curation Studio:
.\citylab.ps1 start

# 4. View curation summary before opening PR:
.\citylab.ps1 summary -City jaipur

# 5. Bake fixes and automatically sync to BOTH DataFactory & YatraCanvas Mobile App:
.\citylab.ps1 export -City jaipur
```

---

## Documentation Links

- [City Lab Curation Studio Architecture](docs/CITY_LAB_CURATION_ARCHITECTURE.md)
- [City Lab Contributor Guide](docs/CITY_LAB_CONTRIBUTOR_GUIDE.md)
- [Curation Rebuild Audit](docs/CITY_LAB_CURATION_REBUILD_AUDIT.md)
- [Bug Audit & Resolutions](docs/CITY_LAB_BUG_AUDIT.md)
- [Quality & Release Gate Architecture](docs/CITY_LAB_QUALITY_ARCHITECTURE.md)
- [Dataset QA Protocol & Tester Guide](docs/DATASET_QA_GUIDE.md)
- [City Pack Schema Audit](docs/CITY_PACK_SCHEMA_AUDIT.md)

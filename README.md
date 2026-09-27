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

The application is structured into 5 cohesive inspection screens:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           YATRACANVAS CITY LAB                              │
├───────────────┬─────────────────┬──────────────┬──────────────┬─────────────┤
│ 1. Overview   │ 2. Data Coverage│ 3. Review    │ 4. Release   │ 5. Pipeline │
│ & Executive   │    & Gaps       │    Queue     │    Gate      │ Diagnostics │
└───────────────┴─────────────────┴──────────────┴──────────────┴─────────────┘
```

### 1. Overview & Executive Summary (`OverviewScreen`)
- **10-Second Executive Scan**: Large release status badge (`READY`, `REVIEW_REQUIRED`, `BLOCKED`) with immediate reason summary.
- **4 Primary KPI Cards**: Data Quality Score, Travel Readiness Score, Manual QA Status (`NOT STARTED`, `PENDING X/50`, or `PASSED`), and Critical Blockers count.
- **Dataset Profile Row**: Total places, Core destinations count, Local images count, DB file size.
- **Critical Blockers Box**: Prominent alert highlighting every blocker preventing release, with direct action buttons to jump to the offending records.

### 2. Data Coverage & Gap Analyzer (`DataCoverageScreen`)
- **Category Coverage Matrix**: Per-category breakdown (Food, Sights, Heritage, Nature, Religious, Shopping, etc.) with Total count, Core count, Recommended count, Photo coverage %, and Opening hours coverage %.
- **Actionable Data Gaps**: Pinpoints missing Core images, places lacking operating hours, and coordinates located outside official city bounding boxes.
- **Interactive Drill-Down**: Tapping any gap opens a bottom sheet listing the exact affected places with direct navigation to inspect them.

### 3. Review Queue & Stratified Sampling (`ReviewScreen`)
- **Stratified Sampling Quota**: Automatically constructs a 50-place verification sample distributed across 5 critical buckets:
  - Top Core Attractions (15 places)
  - Recommended Highlights (15 places)
  - Food & Cafes (8 places)
  - High-Relevance Discovery (7 places)
  - Hidden Gems / Long-Tail (5 places)
- **Place Card QA Inspector**: Displays place identity, tier badge, local photo, tags, coordinates, and explainable quality assessment badges (`Clean`, `In City Bounds`, `Multi-Source`, `Hero Photo`).
- **Defect Logging**: One-click actions to Approve (`LOOKS GOOD`) or Flag with standard defects (`WRONG_CATEGORY`, `WRONG_LOCATION`, `BAD_IMAGE`, `WRONG_NAME`, `DUPLICATE`, `NOT_TRAVEL_RELEVANT`, `SHOULD_NOT_BE_CORE`, `STALE_CLOSED`).

### 4. Release Gate Certification (`ReleaseGateScreen`)
- **Deterministic Rules Evaluation**: Tests the pack against 7 rigorous gates:
  - Core coordinate integrity (100% inside city bounds)
  - Minimum Core image coverage (>= 60%)
  - Minimum Core places count (>= 5)
  - Minimum Data Quality score (>= 70.0)
  - Minimum Travel Readiness score (>= 60.0)
  - Mandatory Manual QA sample (>= 50 places reviewed)
  - Maximum defect rate (<= 10%)
- **Certified Artifact Export**: Generates production certification bundle:
  - `release.json`: Machine-readable pass/fail release manifest.
  - `quality_report.json`: Full 8-dimension data quality + 5-dimension travel readiness breakdown.
  - `release_report.md`: Human-readable markdown audit summary.

### 5. Pipeline Diagnostics (`DiagnosticsScreen`)
- **DataFactory Candidate Funnel**: Inspects upstream pipeline extraction, deduplication, and anomaly filtering.
- **Strict Decoupling**: Visualizes raw candidate rejections and filter loss without contaminating the active city quality score.

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
│   ├── app_state.dart              # Global reactive state & Quality Engine evaluator
│   └── routes.dart                 # Application navigation routes
├── data/
│   ├── city_pack_database.dart     # SQLite reader, aggregates & coverage matrices
│   ├── city_pack_loader.dart       # Copies & loads bundled SQLite packs
│   └── local_place_repository.dart # Place repository contract & implementation
├── domain/
│   ├── city.dart                   # City entity & bounding box
│   └── lab_place.dart              # Place model with convenience getters
├── quality/
│   ├── config/
│   │   ├── quality_weights.dart    # 8-dimension weights (Core 0.25, Geo 0.20...)
│   │   ├── travel_readiness_weights.dart # 5-dimension weights (Depth 0.30...)
│   │   └── release_gate_config.dart# Gate thresholds (Sample=50, DQ=70, TR=60)
│   ├── models/
│   │   ├── data_gap_item.dart      # Missing photo, hours, or boundary gap
│   │   ├── data_quality_score.dart # Overall DQ score & dimension breakdown
│   │   ├── manual_qa_summary.dart  # 4-state Manual QA lifecycle model
│   │   ├── place_quality_assessment.dart # Explainable per-place QA flags
│   │   ├── quality_dimension.dart  # Generic quality dimension container
│   │   ├── release_gate_result.dart# Release gate outcome (READY, REVIEW, BLOCKED)
│   │   └── travel_readiness_score.dart # Travel viability score model
│   └── services/
│       ├── city_quality_service.dart   # Evaluates 8 data quality dimensions
│       ├── data_gap_service.dart       # Analyzes coverage gaps & outliers
│       ├── qa_sampling_service.dart    # Generates stratified 50-place sample
│       ├── release_gate_service.dart   # Enforces hard blockers & release status
│       └── travel_readiness_service.dart# Evaluates 5 travel readiness dimensions
├── qa/
│   ├── qa_export_service.dart      # Generates release.json & quality_report.json
│   └── qa_repository.dart          # Reads/writes isolated QA reviews in AppDocuments
├── screens/
│   ├── city_lab_home_screen.dart   # Top navigation shell across the 5 pillars
│   ├── city_pack_screen.dart       # Pack selector & metadata viewer
│   ├── data_coverage_screen.dart   # Category coverage matrix & Data Gap Analyzer
│   ├── diagnostics_screen.dart     # Isolated candidate funnel & pipeline metrics
│   ├── overview_screen.dart        # 10-second executive scan & KPI cards
│   ├── release_gate_screen.dart    # Gate checklist & certified artifact export
│   └── review_screen.dart          # Stratified QA sampling queue & defect logger
└── widgets/
    ├── place_card.dart             # Cross-platform place card with image fallback
    └── score_ring.dart             # Circular score indicator with tier colors
```

---

## Documentation Links

- [Quality & Release Gate Architecture](docs/CITY_LAB_QUALITY_ARCHITECTURE.md)
- [System Architecture](docs/LAB_ARCHITECTURE.md)
- [Dataset QA Protocol & Tester Guide](docs/DATASET_QA_GUIDE.md)
- [Quality Gate Audit & Rationale](docs/CITY_LAB_QUALITY_GATE_AUDIT.md)
- [City Pack Schema Audit](docs/CITY_PACK_SCHEMA_AUDIT.md)
- [City Pack Size & Capacity Report](docs/CITY_PACK_SIZE_REPORT.md)
- [Lab Environment Report](docs/LAB_ENVIRONMENT.md)

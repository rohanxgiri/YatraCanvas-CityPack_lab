# AGENTS.md — YatraCanvas CityPack Lab

**Data Quality, Travel Readiness & Production Release Gate System**  
*Repository Context and Operational Guidelines for AI Coding Agents*

---

## 1. Project Purpose & Role in YatraCanvas Ecosystem

`YatraCanvas-CityPack-Lab` is **NOT** a standard consumer travel application. It is the **Quality Assurance, Travel Readiness & Release Certification Gatekeeper** for city pack datasets produced by `YatraCanvas-DataFactory`.

Before any city pack (e.g., Jaipur, Manali, Rishikesh, Panaji, Gulmarg) can be merged, bundled, or downloaded in the main YatraCanvas mobile app, it must pass through City Lab to answer:
1. Is the data structurally complete and clean? (**Data Quality Score**)
2. Is the data viable for generating multi-day tourist itineraries? (**Travel Readiness Score**)
3. What is missing? (Hero photos, operating schedules, category depth via **DataGapService**)
4. What records are suspicious or flawed? (Evaluated in **ReviewScreen** with stratified sampling)
5. Can this city pack safely ship to production? (**ReleaseGateService**: `READY`, `REVIEW_REQUIRED`, `BLOCKED`)

---

## 2. Invariants & Non-Negotiables

Every AI agent working on this codebase **MUST strictly uphold** the following invariants:

1. **Read-Only SQLite Input**:
   - The shipped database `yatracanvas.db` in `assets/city_packs/` is strictly immutable.
   - **NEVER** write, update, or alter tables in `yatracanvas.db`. All connections must be opened read-only.
2. **Zero Remote POI Enrichment**:
   - The lab makes **zero external network requests** for place data (no Google Places, Geoapify, Foursquare, Overpass, or YatraCanvas backend APIs).
   - Data quality is evaluated strictly on what is bundled in the pack.
3. **No Fabricated Quality**:
   - When zero manual reviews exist, the Manual QA status **MUST** report `NOT_STARTED` (never 100% or passing).
   - Review sample sizes below the configured threshold (50 places) report `IN_PROGRESS (X/50)` and act as an active release blocker.
4. **Critical Gates Override Averages**:
   - A high composite quality score (e.g. 95/100) **CANNOT** override a critical failure.
   - If a Core destination is outside city bounds, or if the 50-item manual sample is incomplete, the release status **MUST BE `BLOCKED`**.
5. **Decoupled Pipeline Diagnostics**:
   - Upstream raw candidate rejections and filter loss belong strictly in `DiagnosticsScreen`.
   - Do **NOT** penalize the certified city pack's `DataQualityScore` for candidates safely filtered out by DataFactory.
6. **Two Independent Quality Engines**:
   - **Data Quality Score (0–100)**: Measures data hygiene, completeness, coordinates, and provenance.
   - **Travel Readiness Score (0–100)**: Measures tourist attraction depth, hero media presence, schedule coverage, and itinerary viability.

---

## 3. Directory Layout & Architecture

```
lib/
├── app/
│   ├── app_state.dart                 # Reactive state; triggers quality engine re-evaluations
│   └── routes.dart                    # Application navigation routes
├── data/
│   ├── city_pack_database.dart        # SQLite queries: aggregates, category coverage, bounds filtering
│   ├── city_pack_loader.dart          # Copies and loads bundled SQLite packs
│   └── local_place_repository.dart    # Repository abstraction over SQLite data
├── domain/
│   ├── city.dart                      # City entity with centroid and bounding box coordinates
│   └── lab_place.dart                 # Place domain model with helper getters
├── quality/
│   ├── config/
│   │   ├── quality_weights.dart       # 8-dimension weights (Core 0.25, Geo 0.20, Metadata 0.15...)
│   │   ├── travel_readiness_weights.dart # 5-dimension weights (Depth 0.30, Category 0.25...)
│   │   └── release_gate_config.dart   # Thresholds: Sample=50, DQ=70.0, TR=60.0, MaxDefect=10%
│   ├── models/
│   │   ├── data_gap_item.dart         # Data gap record (missing photo, missing hours, outlier)
│   │   ├── data_quality_score.dart    # 8-dimension score model with explainability
│   │   ├── manual_qa_summary.dart     # 4-state lifecycle model (NOT_STARTED, IN_PROGRESS, SUFFICIENT)
│   │   ├── place_quality_assessment.dart # Per-place explainable tags (Clean, InBounds, MultiSource)
│   │   ├── quality_dimension.dart     # Generic quality dimension container
│   │   ├── release_gate_result.dart   # Release gate outcome (READY, REVIEW_REQUIRED, BLOCKED)
│   │   └── travel_readiness_score.dart# 5-dimension travel readiness score model
│   └── services/
│       ├── city_quality_service.dart  # Evaluates 8 data quality dimensions
│       ├── data_gap_service.dart      # Discovers category gaps, missing photos, and outliers
│       ├── qa_sampling_service.dart   # Builds stratified 50-place QA queue across 5 buckets
│       ├── release_gate_service.dart  # Applies 7 deterministic gates and blocker overrides
│       └── travel_readiness_service.dart # Evaluates 5 travel readiness dimensions
├── qa/
│   ├── qa_export_service.dart         # Generates release.json, quality_report.json, release_report.md
│   └── qa_repository.dart             # Reads/writes isolated QA reviews to AppDocuments
├── review/
│   ├── models/
│   │   ├── inbox_decision.dart        # Human verdicts, notes, and changed-since-review snapshots
│   │   └── review_candidate.dart      # DataFactory review_candidates.json domain model
│   ├── repository/
│   │   └── inbox_decision_repository.dart # Git-trackable per-entity JSON storage (curation/inbox_decisions/)
│   └── services/
│       ├── review_manifest_loader.dart    # Loads and sorts candidate manifest
│       └── review_reason_translator.dart  # Translates machine codes to human explainable reasons
├── screens/
│   ├── city_lab_home_screen.dart      # Top navigation container for the studio tabs
│   ├── city_pack_screen.dart          # City pack selection and metadata view
│   ├── home_screen.dart               # Executive overview & priority task runway
│   ├── overview_screen.dart           # Pillar 1: 10-second executive scan & KPI cards
│   ├── data_coverage_screen.dart      # Pillar 2: Category coverage matrix & Data Gap Analyzer
│   ├── review_inbox_screen.dart       # Human review inbox for DataFactory review_candidates.json
│   ├── review_screen.dart             # Pillar 3: Stratified 50-item QA queue & defect logger
│   ├── release_gate_screen.dart       # Pillar 4: 7-gate checklist & certified artifact export
│   └── diagnostics_screen.dart        # Pillar 5: Isolated candidate funnel & pipeline metrics
└── widgets/
    ├── place_card.dart                # Cross-platform place card with image fallbacks
    ├── review/
    │   ├── review_candidate_card.dart # Compact card with priority, verdict, and quick actions
    │   └── review_detail_panel.dart   # Deep-inspection side panel (signals, OSM, completeness)
    └── score_ring.dart                # Visual circular score gauge
```

---

## 4. Key Workflows & Commands

### Running Locally
```bash
# Web / Chrome (uses sqflite_common_ffi_web with WASM)
flutter run -d chrome

# Desktop / Android
flutter run
```

### Running Tests
```bash
# Run entire test suite (all tests must pass 100%)
flutter test

# Run review inbox suite (parsing, filtering, translation, change detection)
flutter test test/review_inbox_test.dart

# Run quality engine rules suite (Synthetic Cases A–F)
flutter test test/quality_engine_test.dart

# Run evaluation on real Jaipur production dataset (10,060 places)
flutter test test/jaipur_quality_eval_test.dart

# Static analysis (zero issues allowed)
flutter analyze
```

### Syncing Packs from DataFactory
```bash
# List available production packs
python tools/sync_city_packs.py --list

# Sync specific city pack into assets/city_packs/
python tools/sync_city_packs.py --cities "Jaipur"
```

---

## 5. Coding & Web Compatibility Guidelines

- **Web / WASM Compatibility**: Never import `dart:io` directly in widgets or services without guarding with `kIsWeb`. Use `LocalImageResolver` or `Image.asset()` for web rendering.
- **Null Safety & Types**: Use strong types everywhere. Ensure all collection types and JSON deserializations are fully typed.
- **Immutability of Data Models**: Prefer immutable data classes (`@immutable`) with `final` fields.
- **State Management**: Reactive evaluations flow through `AppState` (`lib/app/app_state.dart`). When manual reviews are logged, call `appState.evaluateQuality()` to refresh all 5 pillars synchronously.

## Agent workflow skills

Read [Agent workflow](docs/AGENT_WORKFLOW.md) before using the project skills.
It records the installed skill paths, compatibility copies, verification commands,
and separate repair and certification handoffs. These repository invariants govern
generic skill defaults. Keep architectural status labels evidence based and make
surgical additions when maintaining curated instructions.

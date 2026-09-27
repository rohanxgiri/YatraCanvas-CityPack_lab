# YatraCanvas CityPack Lab Architecture

**System Architecture & Quality Gate Design**  
*Document Version: 2.0 (Post-Quality Gate Redesign)*  
*Target: YatraCanvas Data Quality, Travel Readiness & Release Certification*

---

## 1. High-Level Architecture Overview

YatraCanvas CityPack Lab is an independent quality engineering and release certification application built with Flutter. It ingests production City Pack releases from `YatraCanvas-DataFactory`, audits them against rigorous quality and itinerary readiness standards, allows human QA testers to conduct stratified evaluations, and exports cryptographically certified release manifests.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        YatraCanvas-DataFactory                         │
│                (READ-ONLY SOURCE / Production Releases)                │
│                   releases/india/*/v3/yatracanvas.db                   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ tools/sync_city_packs.py
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     Bundled Pack Assets (Read-Only)                    │
│   assets/city_packs/<city>/                                            │
│     ├── yatracanvas.db (SQLite database)                               │
│     ├── manifest.json                                                  │
│     ├── city.json                                                      │
│     ├── lab_sync_receipt.json                                          │
│     └── images/ (<place_id>/*.webp)                                    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ CityPackLoader (Copies & Opens Read-Only)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   App Support Storage (Runtime SQLite)                 │
│        Desktop/Mobile: AppSupport/city_packs/<city>/yatracanvas.db     │
│        Web/WASM: IndexedDB backed via sqflite_common_ffi_web           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ CityPackDatabase
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     CityPackDatabase Query Layer                       │
│    - SQLite LIKE & Index Search                                        │
│    - Category Coverage & Aggregation Matrix                            │
│    - Geographic Bounding Box Integrity Filtering                      │
│    - Paged Traversal (LIMIT / OFFSET)                                  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ LocalPlaceRepository
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      Quality & Evaluation Engines                      │
│   ┌───────────────────────────┐     ┌──────────────────────────────┐   │
│   │    CityQualityService     │     │    TravelReadinessService    │   │
│   │ 8-Dimension Cleanliness & │     │ 5-Dimension Itinerary        │   │
│   │ Completeness Score (0-100)│     │ Viability Score (0-100)      │   │
│   └─────────────┬─────────────┘     └──────────────┬───────────────┘   │
│                 │                                  │                   │
│                 ▼                                  ▼                   │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                      ReleaseGateService                        │   │
│   │    7 Hard Blockers & Safety Overrides -> READY/REVIEW/BLOCKED  │   │
│   └─────────────────────────────▲──────────────────────────────────┘   │
│                                 │                                      │
│                 ┌───────────────┴───────────────┐                      │
│                 │      QaSamplingService        │                      │
│                 │ Stratified 50-Item QA Queue   │                      │
│                 │ (4-State Lifecycle Engine)    │                      │
│                 └───────────────────────────────┘                      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ AppState (StateNotifier / Inherited)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                       Flutter UI Shell (5 Pillars)                     │
│  1. Overview & Executive Scan (`OverviewScreen`)                       │
│  2. Data Coverage & Gap Analyzer (`DataCoverageScreen`)                │
│  3. Review Queue & Stratified Sampling (`ReviewScreen`)                │
│  4. Release Gate Certification & Export (`ReleaseGateScreen`)          │
│  5. Candidate Pipeline Diagnostics (`DiagnosticsScreen`)               │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ QaExportService
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│               Certified Production Artifacts (Exported)                │
│       AppDocuments/qa_exports/<city>_release.json                      │
│       AppDocuments/qa_exports/<city>_quality_report.json               │
│       AppDocuments/qa_exports/<city>_release_report.md                 │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Quality & Release Engine Components

### A. Data Quality Engine (`CityQualityService`)
Measures the completeness, accuracy, and structural cleanliness of the dataset across 8 weighted dimensions:

1. **Core Destination Quality (Weight: 0.25)**:
   - Validates identity fields, English and Hindi names, presence of hero photos, operating hours, and Wikidata provenance on all places flagged as `core_destination`.
2. **Geographic & Identity Integrity (Weight: 0.20)**:
   - Validates coordinates against city bounding box bounds extracted from the `cities` table. Penalizes null, zero, inverted, or out-of-bounds coordinates.
3. **Metadata Completeness (Weight: 0.15)**:
   - Global presence of opening hours, phone numbers, websites, and local descriptions.
4. **Category & Entity Quality (Weight: 0.10)**:
   - Evaluates whether places are mapped to standard YatraCanvas taxonomy and checks for contradictory entity classifications.
5. **Uniqueness & Consistency (Weight: 0.10)**:
   - Analyzes spatial overlap and name similarity to ensure duplicate records were pruned by the pipeline.
6. **Source Provenance Quality (Weight: 0.10)**:
   - Calculates the ratio of places backed by multi-source verification (e.g. OpenStreetMap + Wikidata + Overture Maps).
7. **Freshness (Weight: 0.05)**:
   - Evaluates record generation timestamp recency against pipeline release metadata.
8. **Manual QA Health (Weight: 0.05)**:
   - Proportional to the human approval rate (active only when sample >= 50).

*Configured in `lib/quality/config/quality_weights.dart`.*

---

### B. Travel Readiness Engine (`TravelReadinessService`)
Answers whether the dataset contains the necessary depth and balance for the YatraCanvas travel engine to build multi-day itineraries:

1. **Core Attraction Depth (Weight: 0.30)**:
   - Ensures sufficient anchor tourist attractions (heritage, culture, natural landmarks) exist to fill 1 to 7 day trips (minimum 5, target 15+).
2. **Category Balance (Weight: 0.25)**:
   - Verifies an equitable distribution of POIs across dining, sights, shopping, and scenic spots without extreme single-category distortion.
3. **Hero Media Availability (Weight: 0.20)**:
   - Ratio of Core and Recommended places that possess locally bundled WebP photos for mobile UI cards.
4. **Operating Schedule Coverage (Weight: 0.15)**:
   - Hours coverage on tourist attractions and dining spots to prevent routing users to closed venues.
5. **Dwell Time & Usability (Weight: 0.10)**:
   - Presence of `recommended_visit_minutes` and family/accessibility attributes required for itinerary planning.

*Configured in `lib/quality/config/travel_readiness_weights.dart`.*

---

### C. Release Gate Service (`ReleaseGateService`)
Acts as the ultimate release gatekeeper. Implements the fundamental principle: **Critical gates override averages**.

#### The 7 Deterministic Gates:
| Gate | Condition | Severity on Failure |
|---|---|:---:|
| **Valid Schema & Database** | DB opens cleanly, places count > 0 | `CRITICAL BLOCKER` |
| **Core Coordinate Integrity** | 100% of Core places within city bounding box | `CRITICAL BLOCKER` |
| **Core Media Sufficiency** | >= 60% of Core places have local hero images | `CRITICAL BLOCKER` |
| **Minimum Core Depth** | >= 5 Core destination landmarks | `CRITICAL BLOCKER` |
| **Data Quality Score** | Overall DQ Score >= 70.0 | `CRITICAL BLOCKER` |
| **Travel Readiness Score** | Overall TR Score >= 60.0 | `CRITICAL BLOCKER` |
| **Manual QA Sample Completed** | >= 50 places manually reviewed | `CRITICAL BLOCKER` |
| **Manual Defect Threshold** | Verified defect rate <= 10.0% | `CRITICAL BLOCKER` |

#### Output Statuses:
- **`READY`**: All 7 gates pass with zero blockers and zero warnings. Pack can be certified and shipped to the travel app.
- **`REVIEW_REQUIRED`**: All critical blockers passed, but non-fatal warnings exist (e.g., opening hours < 50% on secondary discovery places).
- **`BLOCKED`**: One or more critical blockers failed. **Release is strictly halted.**

---

### D. Data Gap Service (`DataGapService`)
Performs structural gap analysis across categories and fields:
- Missing Core photos (exact IDs and names).
- Missing operating hours on food, cafes, and attractions.
- Coordinate outliers (places whose coordinates lie outside `[min_lon, min_lat, max_lon, max_lat]`).
- Empty / sparse categories that fall below travel minimums.

---

### E. Stratified QA Sampling Service (`QaSamplingService`)
Replaces unguided browsing with a scientifically stratified review queue:
- **Bucket 1**: Top Core Destinations (Target: 15 places)
- **Bucket 2**: Recommended Highlights (Target: 15 places)
- **Bucket 3**: Food & Cafes (Target: 8 places)
- **Bucket 4**: High-Relevance Discovery (Target: 7 places)
- **Bucket 5**: Hidden Gems / Long-Tail (Target: 5 places)

Total quota: **50 places**. Tracks review lifecycle:
`NOT_STARTED` (0) ➔ `IN_PROGRESS` (1–49) ➔ `SUFFICIENT_SAMPLE` (50+).

---

## 3. Storage Architecture & Immutability Guarantees

```
Storage Roots
├── assets/city_packs/             (READ ONLY: Shipped release bundles)
├── AppSupport/city_packs/         (RUNTIME READ-ONLY: Copied SQLite instance)
├── ApplicationDocuments/
│   ├── qa_sessions/               (READ/WRITE: Reviewer annotations & flags)
│   │   └── qa_<city>.json
│   └── qa_exports/                (READ/WRITE: Certified release artifacts)
│       ├── <city>_release.json
│       ├── <city>_quality_report.json
│       └── <city>_release_report.md
```

- **Zero DB Writes**: `yatracanvas.db` is opened strictly read-only.
- **Annotation Isolation**: Manual approvals and defect logs are written exclusively to `qa_<city>.json` in user documents.
- **Certified Artifacts**: Exported release bundles contain checksums of the audited database and complete scores.

---

## 4. Multi-Platform Support & Web WASM

The application supports cross-platform execution:
1. **Web (Chrome / Edge)**:
   - Uses `sqflite_common_ffi_web` with SQLite WASM.
   - Loads SQLite databases directly into IndexedDB memory.
   - Place card images resolve via `Image.asset()` for bundled city pack images.
2. **Windows Desktop & macOS**:
   - Uses `sqflite_common_ffi` with native `sqlite3` dynamic libraries.
   - Resolves images via `Image.file()` from unpacked directory structures.
3. **Android & iOS**:
   - Uses native `sqflite` with SQLite platform channels.
4. **Headless VM Test Runner**:
   - Executes full integration and evaluation tests via `flutter test` without a display server.

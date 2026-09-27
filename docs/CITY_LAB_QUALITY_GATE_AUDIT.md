# City Lab Quality Gate Audit
**Document**: `docs/CITY_LAB_QUALITY_GATE_AUDIT.md`  
**Date**: September 27, 2026  
**Context**: YatraCanvas City Pack Lab (QA & Production Release Gate System)

---

## 1. Existing Architecture & Data Flow

```text
┌────────────────────────────────────────────────────────┐
│            YatraCanvas-DataFactory (Pipeline)          │
│   • Crawls Overture, OSM, Wikidata, Wikivoyage         │
│   • Deduplicates, scores, tiers, merges sources        │
│   • Generates release directory:                       │
│     releases/india/<state>/<city>/v3/                  │
│     - yatracanvas.db (SQLite)                          │
│     - manifest.json                                    │
│     - city.json, checksums.json, images/               │
│     - places.json, places.parquet, quality_report.html  │
└──────────────────────────┬─────────────────────────────┘
                           │ Read-Only Sync (tools/sync_city_packs.py)
                           ▼
┌────────────────────────────────────────────────────────┐
│             assets/city_packs/<cityId>/                │
│   • yatracanvas.db (ReadOnly SQLite, FFI/WASM)         │
│   • manifest.json (Production Release Manifest)        │
│   • city.json, checksums.json, license_manifest.json   │
│   • images/ (Local WebP files)                         │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│             YatraCanvas-CityPack-Lab (App)             │
│   • Data Layer: CityPackDatabase, LocalPlaceRepository │
│   • QA Layer: QaRepository, QaExportService           │
│   • Isolated Session Storage:                          │
│     qa_sessions/qa_<cityId>.json                       │
└────────────────────────────────────────────────────────┘
```

### Key Observations:
1. **Separation of Responsibilities**:
   - `YatraCanvas-DataFactory` **generates & normalizes** place data.
   - `YatraCanvas-CityPack-Lab` **measures, reviews & certifies** dataset quality.
   - `YatraCanvas` (Main App) **consumes certified release packs**.
2. **Immutability Principle**:
   - `yatracanvas.db` in `assets/city_packs/` is opened in `READ-ONLY` mode.
   - All QA annotations, issues, and audit decisions are stored externally in `qa_sessions/qa_<cityId>.json` (or browser memory in Chrome).

---

## 2. Existing Data Availability & Audit Matrix

Every proposed metric must have a verified underlying data source in the existing pipeline or database:

| Metric / Attribute | Available? | Source | Reliable? | Notes & Implementation Rules |
|---|:---:|---|:---:|---|
| **Total Places Count** | **YES** | `places` table (`COUNT(*)`) & `manifest.json` (`counts.accepted`) | **YES** | Exactly matches across SQLite and manifest. |
| **Core Destinations Count** | **YES** | `places.tier = 'core_destination'` | **YES** | Core tier reflects top tourist landmarks. |
| **Tier Distribution** | **YES** | `places.tier` (`core_destination`, `recommended`, `discovery`, `support`) | **YES** | Indexed column `idx_places_tier`. |
| **Category & Subcategory** | **YES** | `places.category`, `subcategory`, `primary_entity_type` | **YES** | Indexed column `idx_places_category`. 14 main travel categories. |
| **Coordinates (Lat/Lon)** | **YES** | `places.latitude`, `places.longitude` | **YES** | Valid float degrees. Indexed in `idx_places_coords`. |
| **City Boundary Bounding Box** | **YES** | `cities` table (`min_lat`, `max_lat`, `min_lon`, `max_lon`) | **YES** | Used to detect spatial outliers outside city service area. |
| **Local Images** | **YES** | `places.primary_image_path` & `place_images` table | **YES** | Local files resolved in `images/`. License and author in `place_images`. |
| **Opening Hours** | **YES** | `places.opening_hours` | **YES** | OSM formatted string or null/empty. |
| **Contact (Website/Phone)** | **YES** | `places.website`, `places.phone` | **YES** | Website present for ~75% in Jaipur; phone in ~20%. |
| **Wikidata ID** | **YES** | `places.wikidata_id` | **YES** | Primary identifier for authority linking. |
| **OSM ID** | **YES** | `places.osm_id` | **YES** | OpenStreetMap node/way/relation reference. |
| **Overture ID** | **YES** | `places.overture_id` | **YES** | Global GERS ID from Overture Maps. |
| **Source Provenance** | **YES** | `place_sources` table (`place_id, source, source_id, retrieved_at`) | **YES** | Records multi-source confirmation across OSM, Overture, Wikidata, Wikivoyage. |
| **Travel Relevance Score** | **YES** | `places.travel_relevance_score` (0.0 to 1.0) | **YES** | Algorithmic tourism relevance from DataFactory. |
| **Prominence Score** | **YES** | `places.prominence_score` (0.0 to 1.0) | **YES** | Algorithmic importance score. |
| **Quality Overall Score** | **YES** | `places.quality_overall` (0.0 to 1.0) | **YES** | DataFactory composite quality score (mean ~0.43). |
| **Anomaly Score** | **YES** | `places.anomaly_score` (0.0 to 1.0) | **YES** | Outlier detection score from DataFactory pipeline. |
| **Tourism Priority** | **YES** | `places.tourism_priority` | **YES** | Feed sorting weight. |
| **Recommended Visit Mins** | **YES** | `places.recommended_visit_minutes` | **YES** | Estimated dwell time for itinerary generation. |
| **Family Friendly Flag** | **YES** | `places.family_friendly` (0 or 1) | **YES** | Persona suitability flag. |
| **Hindi Place Name** | **YES** | `places.name_hi` | **YES** | Localized Hindi name where available. |
| **Textual Description** | **NO** | Not in `places` SQLite table | **NO** | `places` schema lacks a `description` column. Must be requested from DataFactory if required. |
| **Candidate Funnel Counts** | **YES** | `manifest.json` (`counts.total_raw_candidates`, `accepted`, `rejected`, `quarantined`) | **YES** | Available in manifest. Must be kept in Pipeline Diagnostics, NOT overall city quality. |
| **Conflict Counters** | **YES** | `manifest.json` (`category_conflicts`, `coordinate_conflicts`, `entity_conflicts`) | **YES** | Upstream conflict volume. |
| **Deduplication History** | **YES** | `manifest.json` (`counts.duplicate_merges`) & Spatial clusters | **YES** | Exact duplicate names are 0; 315 spatial coordinate overlap clusters exist in Jaipur. |
| **Manual QA Progress** | **YES** | `qa_sessions/qa_<cityId>.json` | **YES** | Stores reviewed places, defect issues, search ratings, landmark checks, scenario trust. |
| **Field-level Freshness** | **PARTIAL** | `place_sources.retrieved_at` & `places.generated_at` | **PARTIAL** | Pipeline run timestamp is known; individual field crawl ages (e.g. specific hours crawl date) are not tracked separately. |

---

## 3. Existing Project Flaws & Root Problems Identified

1. **Manual QA False Precision Bug**:
   - In previous UI, 0 manual reviews caused `issueRate = 0.0%`, displaying an illusion of 100% manual health.
   - **Fix**: Non-negotiable state machine: `NOT_STARTED` (0 reviews), `IN_PROGRESS` (< minimum sample), `SUFFICIENT_SAMPLE` (>= minimum sample). Zero reviews must **never** yield a 100% score.
2. **Quality vs Rejection Conflation**:
   - Rejection rate from raw candidates was historically conflated with pack quality. High rejection of junk is actually a sign of a good pipeline.
   - **Fix**: Pipeline Diagnostics is strictly isolated from the City Pack Quality Score.
3. **Missing "Travel Readiness" Metric**:
   - A dataset can have clean coordinates and valid names, but contain 90% hotels and 0 viewpoints, making it useless for traveler itineraries.
   - **Fix**: Implement two independent scores:
     - **Data Quality Score** (cleanliness, completeness, consistency)
     - **Travel Readiness Score** (itinerary-worthiness, attractions, category balance, core landmark health)
4. **Weighted Averages Hiding Critical Blocker**:
   - If a city has 95% overall completeness but 4 Core POIs have broken coordinates or are outside the city, an aggregate score of 91 hides the blocker.
   - **Fix**: Explicit **Release Gate Engine** where critical rules trigger `BLOCKED` status regardless of aggregate score.
5. **No Visual Data Gap Drill-down**:
   - Testers saw "53 with images, 10007 no images" but could not click to see which Core landmarks were missing images.
   - **Fix**: Data Coverage Matrix and Gap Analyzer with 1-click drill-down to affected records.

---

## 4. Architectural Boundaries

- **YatraCanvas-DataFactory Contract**:
  - Lab consumes `yatracanvas.db` and `manifest.json`.
  - Lab does not rewrite or rebuild DataFactory releases.
  - Missing fields (like textual `description`) are formally documented as DataFactory requests.
- **YatraCanvas Contract**:
  - YatraCanvas will consume packs only when `release_status == READY` as certified in `release.json`.

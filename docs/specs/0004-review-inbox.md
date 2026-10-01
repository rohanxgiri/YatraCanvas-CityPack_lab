# 0004 Review Inbox — Human In The Loop Candidate Curation

**Status**: Implemented
**Date**: 2026-10-01

## Summary

Integrate DataFactory Quality Pass 2 outputs (`review_candidates.json`) into CityPack Lab to establish a human review, approval, rejection, and correction interface ("Review Inbox"). City Lab remains strictly a curation, quality, and certification environment — never performing bulk scraping, enrichment, or modifying immutable SQLite databases. Human verdicts are stored as individual git-trackable JSON records in `assets/city_packs/<city>/curation/inbox_decisions/<canonical_id>.json`.

## Context & Responsibility Boundaries

Before this integration, human curators lacked visibility into ambiguous or borderline places flagged by DataFactory's travel relevance pipeline (e.g., secondary commercial destinations, contradictory building/amenity tags).

The boundary between systems is strictly maintained:

```text
DataFactory
    ↓
Discover → Filter → Resolve → Enrich → Score → Generate review_candidates.json → Build city pack

City Lab
    ↓
Inspect → Review → Approve (Keep) → Reject (Exclude) → Flag (Needs Research) → Certify → Export
```

### Invariants Maintained
1. **Read-Only SQLite**: Shipped `yatracanvas.db` is strictly immutable.
2. **Zero Remote POI Enrichment**: Zero network requests to Google Places, Geoapify, OSM, or backends.
3. **Decoupled Diagnostics**: Upstream candidate rejections belong in diagnostics/reporting, not penalized in certified city pack quality scores.
4. **Git-Trackable Decisions**: Curation decisions are saved as isolated, diffable JSON files per entity.
5. **Graceful Degradation**: Packs without `review_candidates.json` show an informative empty state with sync instructions rather than crashing.

## Architecture & Data Flow

### 1. Data Models (`lib/review/models/`)
- **`ReviewCandidate`**: Matches DataFactory v3 schema with `canonical_id` as primary identifier (stable across pipeline rebuilds). Parses scores, confidence, priority (`HIGH`/`MEDIUM`/`LOW`), OSM tags, source provenance, and missing fields.
- **`InboxDecision`**: Records human verdict (`unreviewed`, `approved`, `rejected`, `edited`, `needs_research`), author, timestamp, optional notes, and a snapshot of candidate state.
- **`InboxDecisionSnapshot`**: Captures reason code, score, confidence, and missing fields to detect upstream pipeline changes.

### 2. Services & Repositories (`lib/review/`)
- **`ReviewManifestLoader`**: Reads `assets/city_packs/<cityId>/review_candidates.json` (filesystem first, then asset bundle). Sorts candidates using `sortForInbox` (High priority first, then Core tier, then confidence proximity to 0.5 decision boundary).
- **`ReviewReasonTranslator`**: Translates technical machine reason codes (e.g. `CONTRADICTORY_BUILDING_AMENITY`, `SECONDARY_COMMERCIAL_REQUIRES_AUDIT`) into clear, human-understandable titles, explanations, and action recommendations. Unrecognized codes gracefully degrade to safe fallbacks.
- **`InboxDecisionRepository`**: Loads, saves, and deletes per-place decisions from `curation/inbox_decisions/`. Implements `detectChanges` comparing existing snapshot against fresh candidate data (flags significant score deltas > 0.05, changed reason codes, or resolved missing fields).

### 3. User Interface (`lib/screens/review_inbox_screen.dart` & `lib/widgets/review/`)
- **`ReviewInboxScreen`**: High-density curation dashboard with:
  - Priority tabs (All, High, Medium, Low)
  - Category, Reason Code, and Tier filter dropdowns
  - Quick status chips (Unresolved, Resolved, Changed Since Review)
  - Group by Reason toggle
  - Bulk approval / exclusion capabilities
  - Infinite scroll pagination (30 items/page)
  - Responsive two-column view with collapsible detail panel
- **`ReviewCandidateCard`**: Summary card featuring priority badge, verdict status, missing field indicators, and fast Keep/Exclude/Review actions.
- **`ReviewDetailPanel`**: Deep inspection sheet exposing place identity, travel relevance signals, OSM tags, source provenance, completeness checklist, technical metadata, and notes.

### 4. Release Gate Integration (`lib/quality/services/release_gate_service.dart`)
- **Gate 8 (Flagship Conflicts Gate)**: If any `core_destination` has an unresolved `CONTRADICTORY_BUILDING_AMENITY` reason in the Review Inbox, release status is automatically `BLOCKED` until a curator reviews and resolves it.

### 5. Home Dashboard & Synchronization
- **`HomeScreen`**: Features an interactive Review Inbox task card in the Priority Work section linking directly to the inbox tab, displaying live unresolved and high-priority candidate counts.
- **`tools/sync_city_packs.py`**: Discovers and syncs `review_candidates.json` from DataFactory `reports/` alongside SQLite and images, while preserving previously indexed city packs in `city_packs_index.json`.

## Testing & Verification
- Unit test suite: `test/review_inbox_test.dart` (30 tests covering deserialization, sorting, serialization, changed detection, and translation).
- End-to-end suite: 77 tests passing across the repository with zero static analysis issues.

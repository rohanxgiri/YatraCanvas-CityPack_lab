# City Lab Bug Audit

**Document**: `docs/CITY_LAB_BUG_AUDIT.md`  
**Date**: September 27, 2026  
**Status**: Audited & Triaged  

---

## Bug Inventory & Root-Cause Analysis

### BUG-01 [CRITICAL]: QA Reviews Trapped in Machine-Local Documents & Zero Curation Storage
- **Severity**: `CRITICAL`
- **Symptom**: Contributors running City Lab review places and flag defects, but their reviews are stored exclusively in their OS `AppDocuments` folder (`qa_<cityId>.json`). Git diffs remain empty, work cannot be shared or submitted via Pull Request, and when DataFactory syncs a new pack, previous reviews are disconnected. Furthermore, there is no mechanism to record actual field corrections (hours, images, coordinates, additions, exclusions).
- **Root Cause**: `QaRepository` hardcodes its destination directory to `getApplicationDocumentsDirectory()/qa_sessions/qa_<cityId>.json` rather than the repository's git-tracked `assets/city_packs/<cityId>/curation/` directory. No entity-level schema exists for overrides, additions, or exclusions.
- **Affected Files**:
  - `lib/qa/qa_repository.dart`
  - `lib/app/app_state.dart`
  - `lib/domain/qa_session.dart`
- **Reproduction**:
  1. Open Jaipur in City Lab.
  2. Approve 5 places in `ReviewScreen`.
  3. Run `git status` in the terminal: zero files modified.
- **Fix**:
  1. Implement a new `CurationRepository` managing entity-level JSON files in `assets/city_packs/<cityId>/curation/` (`overrides/`, `additions/`, `exclusions/`, `reviews/`, `issues/`).
  2. Implement an overlay resolver that computes `CuratedPlace` and updates quality scores.
- **Regression Test**: Test that adding a review or override writes an individual JSON file inside `assets/city_packs/<cityId>/curation/` and updates runtime quality stats.

---

### BUG-02 [HIGH]: Categorization Mismatch in `ReleaseGateService`
- **Severity**: `HIGH`
- **Symptom**: In `ReleaseGateService` Gate 5 ("Itinerary Sights Minimum"), the check for cultural sights searches for categories `attraction`, `monument`, `temple`. In the real Jaipur SQLite database and `manifest.json`, the taxonomy records these as `heritage`, `religious`, `museum`, `viewpoint`, `park`. In smaller cities with fewer parks, Gate 5 fails erroneously even if dozens of heritage temples exist.
- **Root Cause**: Category name hardcoding in `ReleaseGateService.dart` (line 76) does not align with the DataFactory taxonomy (`heritage`, `religious`, `nature`, `arts_culture`).
- **Affected Files**:
  - `lib/quality/services/release_gate_service.dart`
- **Reproduction**:
  1. Inspect `manifest.json` for Jaipur: `heritage: 208`, `religious: 163`, `museum: 40`, `park: 119`.
  2. Review `ReleaseGateService.evaluate`: checks `categoryCounts['attraction']` (0) and `categoryCounts['monument']` (0).
- **Fix**: Update `ReleaseGateService` to aggregate all travel-relevant sight categories (`heritage`, `religious`, `museum`, `viewpoint`, `park`, `nature`, `arts_culture`, as well as legacy `attraction` and `monument`).
- **Regression Test**: Assert that a city pack containing only `heritage` and `religious` places successfully passes the attraction count gate.

---

### BUG-03 [HIGH]: Review Queue Regresses/Loops Over Already-Reviewed Places
- **Severity**: `HIGH`
- **Symptom**: When reviewing the 50-place stratified sample in `ReviewScreen`, navigating away or reopening the screen restarts at index 0 and presents already-reviewed places again.
- **Root Cause**: `ReviewScreen._loadPlaces()` invokes `qaSamplingService.generateSample()` without filtering out place IDs that have existing review records in the session.
- **Affected Files**:
  - `lib/screens/review_screen.dart`
  - `lib/quality/services/qa_sampling_service.dart`
- **Reproduction**:
  1. Go to `ReviewScreen` for Jaipur.
  2. Approve place 1.
  3. Switch to `OverviewScreen` and return to `ReviewScreen`.
  4. Place 1 is displayed again.
- **Fix**: Exclude already-reviewed place IDs from the unreviewed queue, displaying clear progress: `X / 50 completed`, with only unreviewed places in the active review stack.
- **Regression Test**: Verify that approved or flagged places do not appear in the active review queue.

---

### BUG-04 [MEDIUM]: Overview Screen Heuristic/Hardcoded Place Counters
- **Severity**: `MEDIUM`
- **Symptom**: In `OverviewScreen`, `readyCount` and `reviewCount` are approximated via `totalPlaces - outsideBounds - sharedCoords`, ignoring missing photos and missing hours, while `excludedCount` is hardcoded to `0`.
- **Root Cause**: Placeholder arithmetic written in the UI widget rather than derived from actual curation and data gap evaluation.
- **Affected Files**:
  - `lib/screens/overview_screen.dart`
- **Reproduction**:
  1. Open `OverviewScreen` for Jaipur: shows 8,582 ready, even though over 9,000 places lack opening hours and photos.
- **Fix**: Calculate actionable counts from real curation state: `Ready` = places without critical gaps; `Needs Attention` = places with active gaps or open issues; `Excluded` = places with manual exclusion records.
- **Regression Test**: Add a manual exclusion and verify `excludedCount` increments and `readyCount` adjusts.

---

### BUG-05 [MEDIUM]: Unconditional `dart:io` Import in `local_place_repository.dart`
- **Severity**: `MEDIUM`
- **Symptom**: Unconditional `import 'dart:io';` at line 1 of `lib/data/local_place_repository.dart`.
- **Root Cause**: Leftover unused import from previous refactoring.
- **Affected Files**:
  - `lib/data/local_place_repository.dart`
- **Reproduction**:
  1. Check line 1 of `local_place_repository.dart`.
- **Fix**: Remove the unused `dart:io` import.
- **Regression Test**: Run `flutter analyze` ensuring zero warnings.

---

### BUG-06 [LOW]: Orphaned Screen Duplication
- **Severity**: `LOW`
- **Symptom**: Screens like `qa_dashboard_screen.dart` remain in `lib/screens/` with outdated flows.
- **Root Cause**: Incomplete cleanup during prior quality gate refactor.
- **Affected Files**:
  - `lib/screens/qa_dashboard_screen.dart`
  - `lib/screens/discover_screen.dart`
- **Fix**: Retire or consolidate outdated testing screens and streamline navigation.

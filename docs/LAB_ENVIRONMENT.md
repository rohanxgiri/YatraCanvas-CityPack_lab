# YatraCanvas CityPack Lab Environment

## Environment Overview

- **Host OS**: Microsoft Windows 11 / Windows Server (Build 26200.9457 x64)
- **Flutter Version**: 3.47.0 (Channel stable, revision `4cf2416426`)
- **Dart Version**: 3.13.0
- **DevTools Version**: 2.60.0
- **Android Toolchain**: Android SDK 36.0.0 (Platform android-37.0, build-tools 36.0.0, Java OpenJDK 25.0.2 JBR)
- **Chrome / Web Engine**: Google Chrome with WASM support via `sqflite_common_ffi_web`
- **Desktop Runtime**: Windows Desktop runner enabled via `sqflite_common_ffi` and `sqlite3_flutter_libs`

---

## Supported Runtime Targets

| Target Platform | Database Driver | Image Resolution | Map Visualization | Primary Use Case |
|---|---|---|---|---|
| **Chrome / Web** | `sqflite_common_ffi_web` (WASM / IndexedDB) | `Image.asset()` | `flutter_map` (OSM tiles + Offline canvas) | Interactive QA auditing, rapid browser review |
| **Windows Desktop** | `sqflite_common_ffi` (Native C DLL) | `Image.file()` / `asset()` | `flutter_map` | High-throughput offline testing & batch reviews |
| **Android / Mobile** | `sqflite` (Platform channels) | `Image.file()` / `asset()` | `flutter_map` | Real mobile device validation (touch & gestures) |
| **Headless Dart VM** | `sqflite_common_ffi` in memory / file | N/A | Mocked / headless | CI/CD automated quality gate verification (`flutter test`) |

---

## Automated Test Suites

The repository maintains 100% passing tests with zero analyzer errors:

```bash
# Full test suite execution
flutter test
```

### Key Test Files:
1. `test/quality_engine_test.dart`:
   - Validates the 6 core behavioral cases (A–F):
     - Case A: High quality dataset produces high DQ score.
     - Case B: Coordinate failure in Core POI triggers immediate release blocker.
     - Case C: Zero manual reviews maintains `NOT STARTED` / `PENDING` (no fabricated 100%).
     - Case D: Dirty upstream candidate pipeline rejections do not depress city pack quality.
     - Case E: Clean dataset lacking attractions triggers Travel Readiness block.
     - Case F: Data gap analyzer pinpoints missing photos, hours, and coordinate outliers.
2. `test/jaipur_quality_eval_test.dart`:
   - Ingests the real production `yatracanvas.db` for Jaipur (10,060 places, v3 release).
   - Evaluates real 8-dimension data quality (65/100), 5-dimension travel readiness (80/100), and release gate blockers.
   - Tests simulated 50-place manual review workflow and verifies status transitions.
3. Unit & Repository Tests:
   - `test/city_pack_database_test.dart`: SQLite search, pagination, category coverage matrix.
   - `test/local_place_repository_test.dart`: Repository abstraction tests.
   - `test/widget_test.dart`: Application boot smoke tests.

---

## Storage & File System Isolation

- **Read-Only Database Source**:
  - `assets/city_packs/<city>/yatracanvas.db`
- **Runtime Local Database**:
  - Desktop/Mobile: `AppSupport/city_packs/<city>/yatracanvas.db`
  - Web: Virtual in-memory IndexedDB database (`db_yatracanvas_<city>.db`)
- **Reviewer Annotations & Sessions**:
  - `AppDocuments/qa_sessions/qa_<city>.json` (strictly isolated from `yatracanvas.db`)
- **Certified Release Exports**:
  - `AppDocuments/qa_exports/<city>_release.json`
  - `AppDocuments/qa_exports/<city>_quality_report.json`
  - `AppDocuments/qa_exports/<city>_release_report.md`

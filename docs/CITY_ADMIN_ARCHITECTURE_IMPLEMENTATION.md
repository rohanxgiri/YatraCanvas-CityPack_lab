# City Admin architecture implementation

**Status**: In progress
**Audit date**: 2026-09-28

## Executive result

The three repositories already contain most of the ingredients for a future City Data admin module. This slice makes the command-line certification path fail closed and makes DataFactory reapply the curation it receives. YatraCanvas has server protected admin APIs, while its Flutter admin flavor remains a separate partial shell with local presentation data. The release path is not yet an end-to-end production UI because the CityPack Lab release screen does not invoke the new command adapter and the current Jaipur media evidence is incomplete.

The safe migration is incremental. CityPack Lab remains the desktop workstation. Reusable rules move behind contracts. Filesystem and sibling repository operations remain adapters. YatraCanvas traveller screens and authentication are not changed in this work.

## Repositories inspected

### YatraCanvas DataFactory

Before this slice, the build order in `datafactory/cli.py` was resolve, extract, normalize, classify, deduplicate, enrich, process images, score, validate, and release. There was no call that read `data/curated/<city>/`. The pipeline now reconciles that directory after provider image processing, scores the reconciled records, restores authoritative human fields after generated scoring defaults, and then validates and releases. It writes a reconciliation report into the city's staging directory and fails on malformed, conflicting, or orphaned human work.

The release writer creates JSON, JSONL, Parquet, SQLite, image metadata, manifests, and checksums. The SQLite schema stores places, tags, sources, and images. Exact canonical place identifiers are the only stable curation key currently available across the repositories.

### YatraCanvas CityPack Lab

The source SQLite database is copied and opened read only for inspection. Curation lives in entity JSON under `assets/city_packs/<city>/curation/`. The current domain already represents overrides, additions, exclusions, reviews, issues, and curated media. Quality and travel readiness calculations are service classes rather than widget calculations.

The former `tools/export_certified_pack.py` was the critical gap. It did not read release gate evidence, treated curation parse failures as warnings, copied the baseline manifest unchanged, and wrote directly into sibling repositories. It has been replaced by a thin adapter over a certification core. Production mode now requires matching `READY` evidence and sufficient manual QA; developer override output is local and non-certified; publication is explicit and staged.

The current curated media records prove the need for fail closed validation. A real Jaipur export audit on 2026-09-28 stopped with four named records whose source page and author fields are blank. It produced no artifact and changed no publication target.

### YatraCanvas

FastAPI protects `/api/admin/*` with bearer authentication and a server side `ADMIN` role in `backend/app/core/auth.py`. This meets the immediate rule that admin access is not based on a Flutter email comparison. The existing role model is coarse, with `USER` and `ADMIN`, and does not yet expose City Data permissions.

The Flutter traveller entry point remains separate from `main_admin.dart`. The Flutter admin flavor is marked partial in repository documentation and contains local presentation data. It is not a suitable release authority today. No traveller Home, Explore, trip, routing, or provider behavior should change in this implementation.

## Documentation mismatches

1. DataFactory documentation described releases accurately, but CityPack Lab documentation implied that copying files into `data/curated/` made curation persistent. This slice adds the missing application stage.
2. CityPack Lab documentation called its release JSON certified even when the release gate was blocked. Release evidence now distinguishes `certified` from `not_certified` and omits a certification timestamp when blocked.
3. The former Python publish tool copied the baseline manifest after database changes, so its output was not cryptographically certified despite the documentation language. The new core regenerates counts, manifests, and hashes from staged output.
4. The CityPack Lab root architecture tree predates the curation studio screens and repository layout shown by the current source.
5. YatraCanvas documents the FastAPI web admin as implemented and the Flutter admin flavor as partial. The source confirms that distinction.

## CityPack Lab subsystem classification

| Subsystem | Classification | Current coupling | Target boundary |
|---|---|---|---|
| `lib/domain/` and `lib/domain/curation/` | Domain logic | Mostly clean Dart models | City Admin core |
| `lib/quality/models/` and `lib/quality/services/` | Domain logic | Pure calculations with application supplied inputs | City Admin core |
| `lib/curation/curation_service.dart` | Domain and application logic | Depends on concrete file repository | Contract based application service |
| `lib/curation/curation_repository.dart` | Data access and platform | Builds local paths and imports `dart:io` | File curation adapter |
| `lib/data/city_pack_database.dart` | Data access | SQLite queries | Local SQLite adapter |
| `lib/data/city_pack_loader.dart` | Platform and filesystem | Asset copy and platform database setup | Local pack storage adapter |
| `lib/data/local_image_resolver.dart` | Platform and filesystem | Platform image paths | Local media adapter |
| `lib/qa/qa_repository.dart` | Data access and platform | Application documents and web memory | Review repository adapters |
| `lib/qa/qa_export_service.dart` | Application and platform | Evidence generation plus direct file writes | Release evidence service plus file adapter |
| `lib/app/app_state.dart` | Application shell | Owns orchestration and UI notifications | Composition root remains in CityPack Lab |
| `lib/screens/` and `lib/widgets/` | Presentation | Flutter and `BuildContext` | Standalone shell now, future Admin City Data surfaces later |
| `tools/sync_city_packs.py` | Developer tooling | Sibling repository and asset layout | Workspace and local pack storage adapter |
| `tools/export_certified_pack.py` | Developer tooling and release adapter | Mixes rules, SQLite, filesystem, and publication | Thin command adapter over certification core |
| `scripts/` and `citylab.ps1` | Developer tooling | Local workspace assumptions | Remain outside the reusable core |

## Before

Business rules and storage are partly separated, but the curation repository, QA repository, and export paths construct filesystem locations directly. The Flutter release evidence generator does not prevent a blocked result from looking certified. The Python exporter is both the curation engine and publisher. DataFactory ignores stored curation during regeneration.

## Target after

```text
DataFactory provider build
        |
        v
human curation applicator
        |
        v
score and validate
        |
        v
CityPack Lab quality and review
        |
        v
certification core
        |
        v
local certified artifact
        |
        v
explicit publisher adapters
```

The core knows city identity, curation records, reconciliation, quality evidence, validation outcomes, and release metadata. It does not know Flutter widgets, `BuildContext`, Git commands, sibling repository locations, or developer specific paths.

## Curation precedence

Values are resolved in this order:

1. Verified human override.
2. Manual addition.
3. Automated canonical provider value.

An exclusion is a durable tombstone. It removes a matched provider entity from a generated release but remains stored even when that entity is absent. An unknown identifier is reported as orphaned and remains available for human reconciliation. Low confidence matching is never automatic.

## Certification process

Production certification is fail closed. It requires explicit `READY` release evidence and sufficient manual QA. Curation is applied to a copied database. The copy must pass SQLite integrity, media path, attribution, and reconciliation checks. Counts, manifests, release metadata, and hashes are then regenerated from the final output. Publication starts only after the local artifact is complete.

A developer force export is local only and marked `non_certified`. It cannot update the YatraCanvas application pack.

## Release artifacts

The certified artifact uses distinct version values:

| Value | Meaning |
|---|---|
| `schema_version` | Changes only when the pack or descriptor format changes |
| `pack_version` | Identifies the DataFactory pack being certified in the first slice |
| `curation_revision` | Deterministic digest of the curation JSON snapshot |
| `release_status` | `certified` or `non_certified` |

There is no separate numeric `release_version` in the first slice. A release is identified by city, source pack version, curation revision, and certified timestamp. A future registry may allocate a monotonic release version without changing those meanings.

The output contains `yatracanvas.db`, `manifest.json`, `image_manifest.json`, `checksums.json`, `release.json`, copied legal and city metadata, and the referenced image files.

## Future YatraCanvas Admin integration

The future route is `AdminShell` to `City Data` to adapters backed by authenticated APIs. Suggested early roles are traveller, editor, and admin. Suggested permissions are `city.read`, `city.edit`, `city.review`, `city.media.edit`, and `city.publish`. Editors do not receive publish permission by default. FastAPI must enforce these permissions even when Flutter hides a route or button.

Screen capability mapping:

| CityPack Lab | Future YatraCanvas Admin |
|---|---|
| Home | City Data Overview |
| Fix Center | City Data Fix Center |
| Review Queue | City Data Reviews |
| Places CMS | City Data Places |
| Image curation | City Data Images |
| Release Gate | City Data Publish |

The future API replaces local JSON and Git as the write adapter. It does not replace the domain models, curation precedence, quality engines, review lifecycle, or release gate.

## What remains intentionally separate

1. CityPack Lab remains a desktop first editor and release workstation.
2. DataFactory remains the automated data generator and does not own manual review UI.
3. YatraCanvas remains the traveller product and API backed admin host.
4. Local image import, workspace editing, and Git curation do not move into the traveller application.

## Files changed

### CityPack Lab

1. `lib/city_admin/contracts/curation_repository_contract.dart` adds a storage-neutral curation boundary.
2. `lib/curation/curation_repository.dart` and `lib/curation/curation_service.dart` route the existing file implementation through that contract.
3. `lib/qa/qa_export_service.dart` emits explicit certified or non-certified release evidence and withholds a certification timestamp when hard gates have not passed.
4. `tools/city_admin_core/certification.py` owns curation application, reconciliation, validation, metadata regeneration, checksums, staging, rollback, and publication rules.
5. `tools/export_certified_pack.py` is a thin command adapter with explicit evidence, local developer export, and publish modes.
6. `test/release_evidence_test.dart` and `tools/tests/test_certification.py` protect gate and artifact behavior.
7. `docs/specs/0003-certified-release-evidence.md`, `docs/scope/scope.md`, and this report record the design and migration status.
8. `README.md` and `citylab.ps1` document and enforce the explicit evidence, developer-export, and publish workflow.

### DataFactory

1. `datafactory/pipeline/curation.py` applies durable additions, exact-ID overrides, exclusions, and attributed media, reports reconciliation, and restores human precedence after scoring.
2. `datafactory/cli.py` invokes curation between image processing and scoring, persists the report, and reapplies authoritative fields before validation.
3. `datafactory/pipeline/release.py` overwrites matching generated media files during a same-version rebuild.
4. `tests/test_curation.py` proves refresh survival, manual precedence, additions, exclusions, media portability, and fail-closed orphan handling.
5. `README.md` documents the curation stage and durable directory contract.

### YatraCanvas

No source files were changed by this task. Traveller behavior and the existing authentication boundary remain untouched; unrelated pre-existing working-tree changes were preserved.

## Tests

Observed on 2026-09-28:

1. CityPack Lab Python certification suite: 8 tests passed.
2. CityPack Lab focused Flutter release evidence suite: 2 tests passed.
3. CityPack Lab full Flutter suite: 47 tests passed.
4. CityPack Lab static analysis: no issues found.
5. DataFactory focused curation suite: 3 tests passed using `unittest` with no external services.
6. Real Jaipur developer export audit: correctly failed with four incomplete media-attribution blockers; the requested output directory was not created.

The complete DataFactory pytest suite was not run in this environment because its development dependencies are not installed in the bundled interpreter. This is a verification limitation, not a passing result.

## DataFactory integration

DataFactory reads the canonical `data/curated/<city_id>/` directory after provider image processing. It applies additions, verified exact-ID overrides, durable exclusions, and attributed media without mutating raw source data. The reconciled set is scored, human fields are restored so generated defaults cannot outrank verified edits, and only then does semantic validation run. Both successful and reconciliation-failed builds can persist a machine-readable staging report. Same-version release generation overwrites matching media bytes so a corrected image is not masked by an older release directory.

## City Lab

The standalone shell, screens, quality engines, review lifecycle, local SQLite loader, and filesystem curation behavior remain in place. The curation service now consumes a contract, release evidence is honest about blocked states, and the command adapter uses the hardened certification core. The remaining shell gap is invoking that adapter from the Release Gate screen and presenting receipts inside the app.

## YatraCanvas

No YatraCanvas source was modified by this task. The traveller application, routes, services, backend providers, and FastAPI authentication behavior therefore remain as they were at audit time. Unrelated existing working-tree changes were preserved. The future Admin integration is a documented boundary only; no security claim is based on Flutter route hiding or an email comparison.

## Remaining limitations

1. Exact canonical identifiers are the only safe reconciliation key in the first slice.
2. Cross repository publication cannot be one operating system transaction. Staging and rollback receipts reduce but do not remove this limit.
3. A reusable Dart package is deferred until a second adapter consumes the boundary.
4. YatraCanvas City Data APIs and UI are not implemented in this task.
5. The CityPack Lab release screen still needs to invoke the hardened certification adapter and display its receipts.
6. Pack version allocation remains owned by DataFactory; this slice certifies the supplied source version rather than introducing a registry or monotonic allocator.
7. Jaipur cannot currently certify because four curated media records lack author and source-page evidence.
8. `city_packs_index.json` generation and traveller consumption are deferred; no traveller integration was added.

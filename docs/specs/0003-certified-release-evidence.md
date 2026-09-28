# 0003 Certified release evidence

**Status**: In Progress
**Date**: 2026-09-28

## Summary

Make CityPack Lab the only authority that can certify and publish a curated city pack. The build keeps the source SQLite pack read only, applies human curation to a copy, validates the result, and regenerates every manifest and checksum from the bytes that will ship. The first delivery is a tested certification core and command line adapter, with the current Flutter shell kept compatible.

## Context

CityPack Lab already records overrides, additions, exclusions, reviews, and curated media. Its current Python exporter bypasses the Flutter release result, treats unreadable curation as warnings, mutates a copied database, then copies the original manifest and publishes directly into sibling repositories. A blocked city can therefore be labelled certified, stale checksums can ship, and missing human edits can go unnoticed.

DataFactory currently moves from automated enrichment and image processing into scoring, validation, and release without applying `data/curated/<city>/`. Copying curation into that directory does not make it durable across rebuilds. YatraCanvas has protected admin APIs, but City Data administration is not yet part of its authenticated admin surface and remains outside this build.

## Requirements

**User stories**:

1. As a release manager, I want publication to require current release gate evidence so that a blocked pack cannot ship.
2. As a curator, I want overrides, additions, exclusions, and verified media to survive automated rebuilds so that provider refreshes never erase reviewed work.
3. As a maintainer, I want explicit reconciliation and validation reports so that no human change or broken artifact disappears silently.

**Acceptance criteria**:

1. **AC-1**: Production publication succeeds only when supplied release evidence has status `READY`, manual QA is sufficient, and the evidence identifies the same city and source pack version.
2. **AC-2**: `BLOCKED` and `REVIEW_REQUIRED` evidence stops production publication before any sibling repository is changed.
3. **AC-3**: `--force-dev-export` may create only a local artifact marked `non_certified`; it must not publish into YatraCanvas and must print a clear warning.
4. **AC-4**: Certification applies verified field overrides after provider data, preserves additions, applies exclusions as durable tombstones, and never changes the source SQLite file.
5. **AC-5**: Exact identity matches are applied. Unknown overrides and exclusions are reported as orphans, remain stored, and block certification. The system never guesses a low confidence match.
6. **AC-6**: The output database passes `PRAGMA integrity_check`, all declared image paths exist inside the pack, and curated media has required source, licence, contributor, dimensions, and hash metadata.
7. **AC-7**: The output manifest, image manifest, checksums, and certified release descriptor are generated from the final database and copied media. Their counts and SHA 256 values match the actual output.
8. **AC-8**: Any parse, curation, validation, reconciliation, or copy failure returns named blockers and leaves production targets unchanged.
9. **AC-9**: Storage contracts separate curation, review, media, pack, and release concerns from Flutter widgets, project paths, and Git operations.
10. **AC-10**: DataFactory has an explicit curation application stage before scoring and semantic validation, with tests proving human precedence and rebuild persistence.
11. **AC-11**: Existing CityPack Lab quality, review, place editing, and media import flows keep their current behavior.
12. **AC-12**: YatraCanvas traveller code and UI remain unchanged. Future City Data integration is documented against server controlled roles and permissions.

## Options considered

### Option 1: Patch the current publish script in place

Keep all curation, validation, artifact generation, and sibling repository copy logic in one script.

**Pros**:

1. Small initial diff.
2. Keeps the current command name.

**Cons**:

1. Business rules remain coupled to filesystem discovery and copy side effects.
2. Unit testing failure boundaries stays difficult.
3. The future API adapter would need to recreate the rules.

### Option 2: Add a reusable certification core with thin adapters

Introduce pure contracts and certification services, then keep the current command and Flutter shell as adapters. Add DataFactory curation application as a separate stage using the same file format.

**Pros**:

1. Supports local files now and an API repository later.
2. Makes validation and reconciliation deterministic and testable.
3. Allows production targets to be updated only after a complete local build succeeds.

**Cons**:

1. Adds an interface boundary and a staged migration.
2. Dart and Python still need an explicitly versioned JSON contract until a shared package boundary is practical.

### Option 3: Move CityPack Lab into YatraCanvas now

Build City Data directly in the existing admin app and retire the standalone workflow.

**Pros**:

1. One visible admin product.

**Cons**:

1. Couples desktop filesystem work to an API backed product before the release workflow is proven.
2. Risks traveller and backend regressions.
3. Violates the requested transition boundary.

## Decision

**Chosen option**: Option 2: Add a reusable certification core with thin adapters.

Use incremental extraction. Pure domain rules own curation reconciliation, release eligibility, artifact validation, and metadata generation. Infrastructure adapters own SQLite copies, local files, Git tracked curation, sibling repository discovery, and final publication.

## Feature design

**Domain model**:

| Entity | Key fields | Rules |
|---|---|---|
| `CityPackIdentity` | `cityId`, `schemaVersion`, `packVersion` | Versions are distinct and never inferred from one another |
| `CurationRevision` | `revision`, `overrides`, `additions`, `exclusions`, `media` | Human records are appendable or replaceable by entity, never deleted by rebuild |
| `ReconciliationReport` | applied counts, orphan identifiers, conflicts, warnings | Every input record appears in one outcome |
| `ReleaseEvidence` | city, pack version, gate status, scores, manual QA state, timestamp | Production requires `READY` and sufficient manual QA |
| `CertificationResult` | status, blockers, warnings, artifact paths, hashes | `certified` only after all validation succeeds |
| `CertifiedRelease` | schema version, pack version, curation revision, certified time, scores, database hash | Values come from current evidence and final output |

**State transitions**:

`source pack` to `staged copy` to `curation applied` to `validated` to `certified local artifact` to `published`.

Any failure moves to `failed` with blockers. `--force-dev-export` moves only to `non_certified local artifact` and can never enter `published`.

**Interface surface**:

| Surface | Inputs | Outputs | Key errors |
|---|---|---|---|
| `CertificationService.build` | source pack, curation snapshot, release evidence, output root, mode | `CertificationResult` | invalid evidence, orphan curation, invalid media, invalid database |
| `ReleasePublisher.publish` | successful certified result, explicit targets | publication receipts | target write or verification failure |
| `CurationApplicator.apply` | provider places, city curation directory | curated places and reconciliation report | malformed record, conflict, orphan |
| `export_certified_pack.py` | city, evidence path, optional local output, optional `--force-dev-export` | human summary and process status | exits nonzero before publication on blockers |

**Value sourcing**:

| Value | Source |
|---|---|
| Gate status and scores | explicit CityPack Lab release evidence |
| Source schema and pack versions | source `manifest.json` |
| Curation revision | deterministic digest of sorted curation JSON inputs |
| Applied counts and orphans | reconciliation against exact place identifiers |
| Database counts | final copied SQLite database |
| Media counts and metadata | final copied image files and media records |
| Database and file hashes | SHA 256 of final output bytes |
| Certified timestamp | one UTC clock value captured after validation |

**Repository contracts**:

1. `CityPackRepository` reads immutable source packs.
2. `CurationRepository` reads and writes human edits without knowing UI or Git.
3. `ReviewRepository` owns manual QA records.
4. `MediaRepository` resolves curated media and attribution.
5. `ReleaseRepository` stores evidence and local certification artifacts.
6. `ReleasePublisher` performs the final external copy only after certification.

**Key invariants**:

1. The source `yatracanvas.db` is always read only.
2. Verified human values override automated provider values.
3. Exclusions remain durable tombstones and additions remain durable manual entities.
4. Critical gate failure always overrides aggregate scores.
5. Artifact metadata describes the final artifact, never the baseline input.
6. Production targets are not modified until a full staged artifact passes validation.
7. Filesystem paths and sibling repository layout stay outside domain and application services.

**Security model**:

The standalone application uses a local contributor identifier for audit records. Future remote writes require an authenticated server role and explicit permissions such as `city.read`, `city.edit`, `city.review`, `city.media.edit`, and `city.publish`. Flutter routing may reflect permissions, but FastAPI must enforce every admin action. No email comparison is an authorization rule.

**Critical test scenarios**:

1. A `READY` fixture builds and publishes a certified pack, verifies **AC-1**, **AC-7**.
2. `BLOCKED` and `REVIEW_REQUIRED` fixtures leave target directories untouched, verifies **AC-2**, **AC-8**.
3. Forced development export is local and marked non certified, verifies **AC-3**.
4. Overrides win after a simulated provider rebuild, exclusions remain absent, and additions remain present, verifies **AC-4**, **AC-10**.
5. Unknown identifiers appear in reconciliation and stop certification, verifies **AC-5**.
6. Missing media, missing attribution, and changed database bytes fail or change hashes as expected, verifies **AC-6**, **AC-7**.
7. Existing Flutter tests and YatraCanvas regression suites remain green, verifies **AC-11**, **AC-12**.

## Build plan

- [x] Write the architecture audit and classify current subsystems, then introduce repository contracts beside existing implementations without changing the shell, satisfies **AC-9**, **AC-11**, **AC-12**.
- [x] Extract a deterministic certification and reconciliation core from the current export script. Keep the legacy command as a thin adapter, satisfies **AC-1** through **AC-8**.
- [x] Add fixture tests for release evidence, reconciliation, media, SQLite integrity, manifests, checksums, and atomic publication, satisfies **AC-1** through **AC-8**.
- [x] Add DataFactory curation application before scoring and validation, plus rebuild survival tests, satisfies **AC-4**, **AC-5**, **AC-10**.
- [ ] Wire the CityPack Lab release screen to the hardened exporter and verify the existing contributor journey, satisfies **AC-1**, **AC-2**, **AC-11**. The evidence schema is wired; the UI command handoff remains.
- [x] Document the future package boundary, YatraCanvas screen mapping, server permissions, release layout, and version meanings, satisfies **AC-9**, **AC-12**.

## Consequences

**Positive**:

1. Publication becomes fail closed and reproducible.
2. Human curation survives automated refreshes.
3. The same core rules can later sit behind an API adapter.

**Negative and tradeoffs**:

1. Production export now requires explicit release evidence.
2. Existing incomplete Jaipur media attribution will block certification until corrected.
3. Cross language contract compatibility requires versioned fixtures and tests.

**Neutral**:

1. CityPack Lab remains desktop first.
2. YatraCanvas Admin remains separate and partial.
3. The reusable module boundary is established before any package split.

## Migration plan

**Strategy**: Strangler migration beside the current shell.

**Phases**:

1. Add contracts, validation, and local certification while preserving existing UI behavior.
2. Route the command and release screen through the new service.
3. Add DataFactory reapplication and prove rebuild persistence.
4. Retire duplicated path construction only after callers and tests use the new adapters.

**Rollback**: Revert adapter wiring while keeping additive contracts and reports. Source packs and curation files remain unchanged.

**Risks**: Historical curation may be incomplete, source schemas differ by pack version, and publishing to multiple repositories cannot be one filesystem transaction. Staging, preflight validation, and per target receipts limit these risks.

## Follow up

1. Complete review coverage and batch operation design before claiming end to end release readiness.
2. Decide when the stable domain folders should become `packages/yatracanvas_city_admin_core` after two adapters use them.
3. Add API backed repositories only when YatraCanvas City Data implementation begins.

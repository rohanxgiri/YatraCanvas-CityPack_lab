# 0001 · Curated media ingestion

**Status**: In Progress
**Date**: 2026-09-27

## Summary

Add a desktop first, offline photo import workflow that creates consistent WebP assets and a deterministic provenance record while keeping `yatracanvas.db` immutable. Browser builds remain useful for inspection and manual QA, but clearly identify media authoring as a desktop capability.

## Context

The current image curator records a string path and attribution note but never creates an image file. This can make a place appear fixed in the curation overlay while the referenced asset does not exist. The pack already uses paired WebP files and rich image metadata, so manual work should produce the same shape without writing to the source database or calling a remote enrichment service.

## Options considered

1. Copy the selected original unchanged. This is simple, but creates inconsistent formats, dimensions, and pack sizes.
2. Add a hosted media service. This would support browser authoring, but adds accounts, network dependency, cost, and a new source of truth before the local workflow is proven.
3. Generate a local WebP pair plus Git tracked provenance. This matches current packs, stays offline, and keeps reviewable changes beside the data. Chosen.

## Requirements

- **AC-1:** A desktop contributor can select one JPG, PNG, or WebP file up to 25 MB from the image curation dialog.
- **AC-2:** The import rejects unreadable files and images smaller than 640 by 480 equivalent resolution with a plain language error before writing anything.
- **AC-3:** A valid import writes `primary.webp` with a maximum long edge of 1600 px and `thumbnail.webp` with a maximum long edge of 480 px under `assets/city_packs/<city>/images/<place>/`.
- **AC-4:** Each import writes one deterministic `curation/media/<place>.json` record with source note, source page, author, licence, original filename, original checksum, output dimensions, contributor, and timestamp.
- **AC-5:** The place override is saved only after the media files and metadata succeed, then quality scores and gap counts refresh through `AppState`.
- **AC-6:** Web builds do not claim to upload into the repository. They show a review only explanation and keep existing image verification and issue reporting available.
- **AC-7:** A newly created image directory is registered in `pubspec.yaml` once so future Flutter builds bundle the imported media.

## Decision

Use the MIT licensed `file_picker` package for native selection and the MIT licensed pure Dart `image` package for decoding, resizing, and WebP encoding. Store the generated media beside the pack images and store editorial provenance in the Git tracked curation layer.

The database stays untouched. The existing field override points at `images/<place>/primary.webp`; the certified export later bakes only that path into its copied database.

## Feature design

### Data model

`MediaCurationRecord` is an entity level JSON document keyed by `placeId` with these required values:

| Field | Type | Rule |
|---|---|---|
| schemaVersion | integer | `1` |
| cityId, placeId | string | nonempty and path sanitized |
| primaryImagePath, thumbnailImagePath | string | pack relative paths |
| originalFilename, originalSha256 | string | preserve source identity without storing the original |
| source, sourcePage, author, license, licenseUrl | string | explicit provenance, page and URL may be blank only for contributor owned work |
| originalWidth, originalHeight | integer | decoded source dimensions |
| primaryWidth, primaryHeight | integer | encoded primary dimensions |
| contributor | string | current contributor identity |
| importedAt | ISO 8601 string | UTC timestamp |

There is one current media curation record per city and place. A replacement overwrites that entity file and its two generated variants, which keeps Git diffs isolated and reversible through version control.

### Interface surface

`CuratedImageImportService.importImage(...)` accepts pack, place, bytes, source filename, provenance, and contributor. It returns the two relative paths and dimensions. It throws a typed validation exception and removes partial output on failure.

The dialog owns file selection and preview. `AppState` owns orchestration: import first, save the field override second, then recalculate quality.

### Value sourcing

| Value | Source |
|---|---|
| City and place identity | `AppState.activePack` and the selected `CuratedPlace` |
| Source bytes and original filename | `file_picker` selected `PlatformFile` |
| Width and height | decoded image bytes |
| Relative output paths | deterministic city and sanitized place ID convention |
| Author, source, source page, licence | persistent labelled fields in the curation dialog |
| Contributor | `AppState.contributorName` |
| Timestamp | UTC `DateTime.now()` at successful import |
| Original checksum | SHA 256 of selected bytes |
| Quality refresh | existing `AppState.saveFieldOverride` evaluation path |

### Invariants

- Never open the bundled SQLite database for writing.
- Never download an image or infer licence metadata.
- Never count a path as an image until both the primary file and metadata record exist.
- Never leave one variant without the other after a failed import.
- Keep browser review and desktop authoring behavior explicit.

### Failure states

- Cancelled picker leaves the dialog unchanged.
- Unsupported, corrupt, oversized, or undersized input shows an actionable inline error.
- A write or manifest update failure reports the failure and does not save the place override.
- Replacing an existing curated image is atomic at the file level using temporary outputs before rename.

### Critical test scenarios

- **AC-1, AC-2:** supported and corrupt bytes, 25 MB boundary, and minimum dimension boundary.
- **AC-3:** landscape and portrait inputs produce bounded primary and thumbnail dimensions at deterministic paths.
- **AC-4:** the metadata record contains complete provenance and the correct SHA 256 value.
- **AC-5:** import failure leaves the database and override layer unchanged; success refreshes the gap counts.
- **AC-6:** web presentation contains no repository write action.
- **AC-7:** repeated registration does not duplicate the asset entry.

## Migration plan

**Strategy:** Replace path only authoring in place while retaining existing verification and issue actions.

**Phases:** Add the service and dependencies, wire `AppState`, then switch the dialog to the new path. Existing overrides remain valid.

**Rollback:** Revert the dialog and dependency changes. Imported files and media records are additive Git files and can be removed or retained without affecting the immutable database.

**Risks:** Large images can block the UI if processed synchronously, asset registration can be malformed by unusual `pubspec.yaml` structure, and partial file writes can leave inconsistent variants. Processing runs asynchronously, registration targets the existing assets list, and temporary files are promoted only after both encodes succeed.

## Build plan

1. Add the two approved packages and implement the byte based validator, resizer, deterministic metadata writer, and asset registration helper. Covers AC-1 through AC-4 and AC-7.
2. Add `AppState.importPlaceImage` so the media write and curation override remain ordered and quality refresh stays synchronous. Covers AC-5.
3. Replace path only curation with file selection, preview, provenance fields, progress, errors, and explicit web review mode. Covers AC-1, AC-2, AC-5, and AC-6.
4. Add service and widget tests for valid conversion, invalid input, size limits, deterministic metadata, and browser safe presentation. Covers AC-1 through AC-7.

## Consequences

The workflow is immediately useful on contributor desktops and adds no server. Generated media increases the Git repository size, which is acceptable for flagship images now and should be revisited before gallery scale. A Flutter restart is required before a newly added asset appears through `Image.asset`; the dialog previews selected bytes immediately and desktop views can resolve the file directly.

## Follow-up

- Add licence manifest aggregation during certified export.
- Consider Git LFS only after measured repository growth warrants it.

## Rationale

The current dialog writes an image path but no image, so it can raise scores without producing a valid asset. A local, deterministic pipeline closes that integrity gap with two mature packages and no infrastructure. The runner up was copying original files unchanged, rejected because it creates inconsistent formats, dimensions, and pack size.

## References

- [file_picker package](https://pub.dev/packages/file_picker)
- [image package](https://pub.dev/packages/image)

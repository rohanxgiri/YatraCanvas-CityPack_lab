# CityPack Lab product audit — 2026-09-28

## Executive finding

The repository already has credible quality and release engines. Its biggest product risk was the contributor layer: the photo action stored a path string without creating an image, while the first screen emphasized dense scores more than the work needed to unblock a release.

This pass fixes that integrity gap and turns the main contributor route into a plain-language sequence: choose a pack, understand why it is blocked, fix priority gaps, complete the required review, and inspect release evidence.

## What changed

- Added real desktop media ingestion that validates a local image, creates primary and thumbnail WebP variants, records SHA-256 and licence attribution, and writes only to the Git-tracked curation layer.
- Kept browser behavior honest: web can review and flag media, but clearly directs contributors to desktop for filesystem writes.
- Replaced the blended health-first home with the actual release status, first blocker, next action, release runway, and independent data-quality and travel-readiness evidence.
- Added responsive desktop rail and compact bottom navigation, a simpler city selector, and shared visual tokens.
- Added four service tests covering successful output, corrupt input, undersized input, and idempotent asset registration.

The immutable `yatracanvas.db` is never changed, and no remote POI enrichment was introduced.

## Jaipur evidence

The real 10,060-place pack remains correctly blocked:

- Data Quality: 65/100
- Travel Readiness: 80/100
- Manual QA: NOT_STARTED, 0/50
- Core destinations missing hero photos: 33
- Core destinations missing opening hours: 63
- Places involved in duplicate-coordinate findings: 982

The app now helps people resolve those gaps; it does not claim that an automated pass is a manual review.

## Ranked next work

### P0 — unblock native contributor verification

Enable Windows Developer Mode so Flutter can create plugin symlinks, then exercise the native file picker against a temporary city-pack fixture. Do not validate by writing into the production Jaipur pack.

### P0 — certify media in exports

Extend the release exporter to verify that every curated image path exists, every media record has licence and attribution, and exported checksums match the bytes copied to DataFactory.

### P1 — make the 50-place review finishable

Show remaining sample coverage by QA bucket, reviewer ownership, and cross-session progress. Add safe batch decisions only for genuinely repetitive defects; preserve per-place evidence.

### P1 — resolve duplicate clusters as clusters

Present all places sharing coordinates together and support explicit keep-separate, merge-candidate, or location-fix decisions. A list of 982 individual warnings is not an efficient human workflow.

### P1 — structure schedules

Replace free-text-only opening-hour fixes with a day-by-day schedule model plus explicit closed, unknown, and seasonal states so itinerary viability can be evaluated reliably.

### P2 — complete the contributor surface

Add automated accessibility and responsive widget checks, audit legacy routes for removal, and consider browser-authored downloadable curation bundles only if desktop contribution becomes a real adoption constraint.

## Open-source choices

The implementation deliberately uses two focused packages instead of importing a large admin platform:

- `file_picker` for native file selection across supported contributor platforms.
- `image` for deterministic local decode, resize, and WebP encoding.

Both keep place data local and preserve City Lab's zero-remote-enrichment rule. For future bulk editorial cleanup, OpenRefine is worth evaluating as a separate offline preparation tool, not as a runtime dependency or release authority.

## Verification record

- `flutter analyze --no-pub`: zero issues
- `flutter test --no-pub -r compact`: 40 tests passed
- Live browser review: selector, Jaipur blocked dashboard, missing-photo queue, and web-safe photo dialog checked at narrow and desktop widths
- Native photo picking: pending Windows Developer Mode

The existing root `AGENTS.md` already captures the repository's non-negotiable release rules; this audit did not weaken or replace it.

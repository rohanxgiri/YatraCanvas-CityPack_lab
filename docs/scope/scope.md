# Scope: YatraCanvas CityPack Lab

YatraCanvas CityPack Lab is the offline curation and release workbench for contributors who certify DataFactory city packs before they reach the consumer app.

**Build approach:** Journey (finish one contributor path from pack selection through release evidence before opening another).
**Workflow:** Beta (build, verify in the real app, then protect the behavior with tests).

## At a glance

| # | Feature | Phase | Status |
|---|---------|-------|--------|
| A | Quality and release engines | Existing | existing |
| B | Git tracked curation layer | Existing | existing |
| 1 | Curated media ingestion | Journey 1 | in-progress |
| 2 | Contributor workbench | Journey 1 | in-progress |
| 3 | Review coverage and batch operations | Journey 2 | planned |
| 4 | Certified release evidence | Journey 3 | in-progress |

## Existing foundation

### A. Quality and release engines · existing
Independent data quality and travel readiness scoring, deterministic hard gates, gap discovery, and the 50 place manual QA lifecycle. code in `lib/quality/`

### B. Git tracked curation layer · existing
Human overrides, additions, exclusions, reviews, and issues live outside the immutable SQLite pack as deterministic entity JSON. code in `lib/curation/` and `assets/city_packs/<city>/curation/`

## Journey 1: Understand and fix the pack

### 1. Curated media ingestion · in-progress
Let a desktop contributor select a real local photo, validate it, create production image variants, record its licence and provenance, and attach it without mutating the shipped database.
**Done when:** a contributor can import one supported image into a city pack, see clear validation errors, and produce Git trackable media plus attribution and override records.
- [x] Design it (spec): `/architect curated media ingestion`
- [x] Build it: `/develop curated media ingestion`
  - [x] Media validation and WebP variant service (AC-1..4)
  - [x] Contributor import dialog and web review mode (AC-5..6)
  - [x] Asset registration and quality refresh (AC-3, AC-7)
- [ ] Verify it: `/check verify curated media ingestion`
- [x] Test it: `/test curated media ingestion`
Spec 0001

### 2. Contributor workbench · in-progress
Replace the dense technical first impression with a responsive workbench that explains the release state in plain language and makes the next useful action obvious.
**Done when:** pack selection, home, navigation, and photo fixing form one clear responsive journey for a first time contributor.
- [x] Design it (spec): `/architect contributor workbench`
- [x] Build it: `/develop contributor workbench`
  - [x] Shared visual system and responsive app shell (AC-1..3)
  - [x] Simpler pack selection and release runway home (AC-4..6)
  - [x] Accessible loading, empty, error, and narrow screen states (AC-7..8)
- [x] Verify it: `/check verify contributor workbench`
- [x] Test it: `/test contributor workbench`
Spec 0002

## Journey 2: Complete manual review

### 3. Review coverage and batch operations · needs a decision
Make the stratified sample easy to finish across sessions, with reviewer ownership, clear remaining buckets, and safe bulk actions for repetitive defects.
**Done when:** a contributor can complete the required 50 place sample without repeats and a release manager can see coverage by tier and category.
- [ ] Design it (spec): `/architect review coverage and batch operations`

## Journey 3: Certify and hand off

### 4. Certified release evidence · in-progress
Join the gate result, curation diff, media attribution, and export receipts into one reviewable certification bundle for DataFactory and the consumer app.
**Done when:** a release manager can inspect every blocker and export a reproducible bundle only when all hard gates pass.
- [x] Design it (spec): `/architect certified release evidence`
- [ ] Build it: `/develop certified release evidence`
  - [x] Repository contracts and architecture audit, AC-9, AC-11, AC-12
  - [x] Deterministic certification and reconciliation core, AC-1 through AC-8
  - [x] DataFactory curation reapplication, AC-4, AC-5, AC-10
  - [ ] City Lab evidence integration and migration documentation, AC-1, AC-2, AC-11, AC-12
- [ ] Verify it: `/check verify certified release evidence`
- [ ] Test it: `/test certified release evidence`

Spec [0003](../specs/0003-certified-release-evidence.md)

## Deferred

- **Browser authoring:** persist browser edits and export them as a mergeable curation bundle.
- **Remote place enrichment:** remains out of scope by policy. City Lab never fetches POI data.
- **Hosted collaboration server:** contributors coordinate through Git until the local workflow proves a server is necessary.

## Legend

`existing` predates this scope. `in-progress` is designed or being built. `planned` is queued. The immutable `yatracanvas.db` remains read only in every phase.

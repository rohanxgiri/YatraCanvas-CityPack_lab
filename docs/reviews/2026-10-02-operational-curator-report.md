# Operational curator report, 2 October 2026

The operational code changes are implemented and verified. **Jaipur remains BLOCKED.** Native UI work was paused at the user's request after seven distinct Jaipur QA inspections. The remaining native acceptance checks and 50 item manual sample are explicitly unfinished. Passing automated tests does not imply completed curator acceptance.

## A. Priority fix

| Selectable Jaipur candidates | Before | After |
|---|---:|---:|
| BLOCKING | 0 | 0 |
| HIGH | 863 | 2 |
| MEDIUM | 1 | 600 |
| LOW | 0 | 262 |
| Total | 864 | 864 |

DataFactory's `travel_relevance.py` assigns HIGH to secondary commercial review candidates when `travel_points >= 2` or multiple sources support them. Positive inclusion evidence therefore made almost the entire queue urgent. The upstream label remains available as diagnostic data. City Lab now computes urgency from tier, published status, semantic reason, coordinate validity, strong category vote conflict, relevance, source support and completeness. Confidence is independent. Core critical conflicts and required published evidence failures are BLOCKING; important recommended conflicts are HIGH; useful secondary uncertainty is MEDIUM; weak discovery and optional support work is LOW. No POI names or target percentages are encoded.

The 13 ambiguous identity groups remain outside selectable inclusion decisions and have their own blocking queue. Their absence from the BLOCKING candidate count does not remove the city level identity gate. Start Here defaults to unresolved Blocking and High; all priorities remain available.

## B. Identity conflicts

| City | Groups found | Members withheld | Resolved this pass | Remaining |
|---|---:|---:|---:|---:|
| Jaipur | 13 | 29 | 0 | 13 |
| Udaipur | 3 | 6 | 0 | 3 |
| Varanasi | 3 | 7 | 0 | 3 |

All real groups contain different source identities sharing a canonical ID in the upstream review artifact. These are not duplicates introduced by combining old and new local manifests. No real resolution was guessed.

Identity Conflicts displays names, coordinates, categories, tier, canonical ID, source IDs, provenance and distance. Curator notes and member snapshots persist separately under `curation/identity_conflicts/`. Merge chooses a survivor, Separate derives stable member identities, Exclude removes an unpublished group, and Research leaves it unresolved. Inclusion is then reviewed independently in Inbox. Changed source evidence reopens a resolution. Published collisions and indistinguishable repeated source identities require upstream repair; unsafe local reassignment is disabled. Python and Dart both enforce these constraints.

## C. Gallery integrity

Counts below are missing file references in each manifest, including primary and thumbnail variants of gallery items. The two image manifests mirror each other; counts are not doubled.

| City | Broken gallery references before | After | Optional gallery items removed | Missing primary/thumbnail references still present |
|---|---:|---:|---:|---:|
| Jaipur | 82 | 0 | 41 | 0 |
| Udaipur | 88 | 0 | 44 | 8 |
| Varanasi | 160 | 0 | 80 | 20 |

The same files were already absent from DataFactory's release directories. Its release gallery arrays advertised unavailable media; City Lab previously copied those references unchanged. Optional gallery entries are now removed during sync, with validation details in the receipt and updated artifact hashes. Primary evidence stays strict. The original before inventory is retained in `2026-10-02-media-integrity-before.json`.

SQLite still contains its original gallery rows because it is immutable. The effective native detail view omits unavailable optional rows, and the certified builder prunes them only in its separate database copy. Existing Jaipur curation also contains 18 primary image overrides pointing to absent files. Those are separate from the source manifest gallery problem and now block certification explicitly.

## D. Graphical sync

Implemented: workbench toolbar → Sync Latest City Packs → configurable DataFactory repository → Verify → available city selection → Sync → before/after place and candidate counts, changed upstream evidence, preserved decisions, reviewed changes and lost curation count. Python/project settings are expandable; technical logs are collapsed by default. Settings persist in local application support, outside Git. The active database closes before replacement and is reopened after success or failure.

The isolated command bridge test exercised discovery and successful sync from a separate source directory, preserved a decision byte for byte, pruned missing optional media, and rejected corrupt SQLite before replacing the local pack. **The new native graphical sync demonstration on real Jaipur is pending because native checks were paused.** This report does not substitute the fixture for that demonstration.

## E. Search, filters and image review

This pass inspected native Jaipur QA records, actual image previews, authors, licenses, source IDs, coordinates and schedules; saved defects through Report QA Issue; and persisted a Needs Research verdict. It uncovered missing source hydration and baseline description mapping, both now fixed.

The requested Jaipur Mandir/Cafe/Lassiwala/Johari/Palace, Udaipur Lake/Palace/Temple/Cafe and Varanasi Ghat/Temple/Cafe/Sarnath native searches, clear behavior and requested filter combinations remain pending. Earlier audit evidence is documented separately and is not claimed as completion here.

Image import tests cover preview selection, author/license/source evidence, recovery from picker failure and safe curated file placement. Certified output tests demonstrate removal without resurrecting an old image, source hash preservation and curation application. **Real native image retain/replacement/removal acceptance is pending.** No external image or POI enrichment API was introduced.

## F. Manual QA

**Jaipur: 7/50. PASS: 0. ISSUES: 6. NEEDS RESEARCH: 1. Remaining: 43.** Udaipur and Varanasi remain NOT_STARTED.

| Inspected record | Saved verdict | Findings |
|---|---|---|
| Jhalana–Amagarh Leopard Conservation Reserve | Missing Expected Information | Existing audit defect retained |
| Haveli | Missing Expected Information | Missing hours; generic identity requires supporting evidence |
| Akshardham Temple | Missing Expected Information | Missing hours; narrow garden preview needs a representative image check |
| Nahargarh Wildlife Sanctuary | Missing Expected Information | Missing core photo and hours |
| Govind Devji Temple | Missing Expected Information | Missing hours; stale optional gallery rows observed |
| Kesar Kyari | Needs Research | Source/media context needs a recheck |
| Chulgiri Digamber Jain Temple | Missing Expected Information | Missing core photo and hours |

Descriptions were initially shown as absent because the model omitted SQLite's description column. That display bug is fixed. Description statements in the saved inspection notes need rechecking in the corrected native app; verdicts were not silently changed. Other recorded schedule/media findings remain.

QA loads full source/image records, supports PASS/ISSUE/Skip/Research and Previous, displays persistent outcome counts and remaining work, and provides Open Place/Fix Now/Recheck. P/I/J/K and arrows avoid text entry and modal dialogs. Editing a field no longer auto approves a record. Issue save failures remain recoverable instead of closing the form as though saved.

## G. Certification blockers

Before: four known Jaipur blockers, identity ambiguity, one core boundary failure, QA 1/50, DQ below 70.

After the current read only engine evaluation: **22 explicit Jaipur blockers**, comprising 18 broken image overrides plus the same four gate categories. QA is now 7/50. DQ remains 58/100 and travel readiness 87/100. The new blockers reflect previously unchecked defects, not a regression in the source pack or a weakened threshold.

Udaipur: DQ 77/TR 80, identity groups unresolved, QA 0/50 and eight missing required media file references in each mirrored manifest. Varanasi: DQ 73/TR 79, identity groups unresolved, QA 0/50 and twenty missing required media file references in each mirrored manifest. Both remain BLOCKED.

## H. Jaipur certification

**BLOCKED.** Exact remaining reasons:

1. Thirteen unresolved identity conflict groups.
2. One core destination fails geographic boundary validation.
3. Manual sample insufficient, seven of fifty reviewed.
4. Data Quality 58/100, below 70.
5. Replacement primary image missing or unsafe for each of these 18 IDs:

```text
yc_in_rj_jaipur_ajmeri_gate
yc_in_rj_jaipur_alice_garg_seashell_museum
yc_in_rj_jaipur_amer_palace
yc_in_rj_jaipur_chulgiri_digamber_jain_temple
yc_in_rj_jaipur_diwan_i_khas
yc_in_rj_jaipur_elejungle_jaipur_elephant_ride
yc_in_rj_jaipur_ganesh_pol
yc_in_rj_jaipur_handicraft_haveli
yc_in_rj_jaipur_iswari_minar_swarga_sali_isarlat
yc_in_rj_jaipur_jaipur_palace
yc_in_rj_jaipur_jhalanaamagarh_leopard_conservation_reserve
yc_in_rj_jaipur_lakkar_haveli
yc_in_rj_jaipur_lohaghar_fort
yc_in_rj_jaipur_nahargarh_wildlife_sanctuary
yc_in_rj_jaipur_nakati_mata_temple
yc_in_rj_jaipur_sawai_mansingh_townhall
yc_in_rj_jaipur_suraj_pol_gate
yc_in_rj_jaipur_vidyadhar_garden
```

Completing 50 inspections will not automatically resolve the six issues or research verdict. Those must be rechecked honestly. Build Certified Pack re-evaluates gates before writing evidence or invoking the canonical builder. Evaluation failures now fail closed, so an earlier READY result cannot survive a failed refresh.

## I. Certified output

No certified Jaipur output was created. Successful controlled certification tests verify SQLite integrity, expected records, exclusions, KEEP/additions/edits, media overrides/removal, regenerated metadata and source preservation. BLOCKED and REVIEW_REQUIRED evidence are rejected before an output directory is created. Graphical build result includes version, actual place count, validation outcomes, evidence and output path. Real native build acceptance remains pending.

Source SQLite hashes match Git HEAD for all three cities:

```text
Jaipur   b96499de299a85d4aedff2ec462e9f0df0a7970ed41921fe9990c4e9d29ccbb7
Udaipur  cf908e4ffe3508b7f4c8689d5ba880d7e96e7dd47bdd436fff3e8114c83c2764
Varanasi ae61f697645e63c012f6cff0b43613d1a8a338f479f448b0608bf554f5ef0b74
```

## J. Fresh setup audit

A separate snapshot under ignored `artifacts/fresh-setup` copied current source, configuration, assets and Windows runner files without `.dart_tool`, plugin ephemeral files or build output. `flutter pub get` succeeded there, and a fresh Windows debug build succeeded in 61.3 seconds. The isolated Python sync test also starts with a separate checkout/source layout. These prove reproducibility on this host, not installation of Flutter, Python or Visual Studio on an untouched laptop.

Documentation now includes the graphical path configuration, sync, blockers, QA and certified build flow. Remaining setup requirements: Git, supported Flutter/Dart, Windows desktop C++ components and a local Python executable. Launch through the checkout's start script so all curation uses that checkout. Configuring another tools project alone does not move the active workspace. No production code/configuration contains the developer's absolute user path; CLI sibling/home discovery remains an optional fallback. Standalone packaged authoring without a writable checkout is not established.

## K. Performance

Measured backend timings on this host, during the full suite:

| Operation | Time |
|---|---:|
| Jaipur manifest parse/load, 893 raw candidates | 165 ms |
| Jaipur database open | 62 ms |
| Published name/category searches | 3–8 ms |
| Full Lake Palace detail lookup | 8 ms |
| Complete Jaipur engine evaluation with curation/media | 408 ms |
| Udaipur engine evaluation | 92 ms |
| Varanasi engine evaluation | 127 ms |

Native frame/input latency, native decision-save latency and native city-switch timings were not measured before the pause. Backend timings are not presented as native UI measurements.

## L. Verification

| Check | Actual result |
|---|---|
| `flutter analyze --no-pub` | Zero issues |
| `flutter test --no-pub --reporter expanded` | 90 passed |
| Python tests, `unittest discover -s tools/tests` | 16 passed |
| `git diff --check` | Exit 0, no whitespace errors |
| Isolated `flutter pub get` | Passed |
| Isolated Windows debug build | Passed |
| Web build and WASM dry run | Passed |

Regression coverage includes impact priority, real distribution, parsing/unknown codes/change detection, effective description preservation, media overrides, optional gallery cleanup, sync preservation and corrupt-source rejection, output image removal, deterministic QA sampling and real city blocker evaluation. Final Flutter evidence is in ignored `artifacts/final-flutter-tests.log`. Git printed normal Windows line-ending conversion notices, not whitespace failures.

## M. Remaining limitations

* Native checks are paused at the user's explicit request. Full Jaipur QA, requested searches/filter combinations, real image actions, graphical sync and graphical build demonstrations are unfinished.
* Real identity decisions and the core coordinate problem require trustworthy evidence; no merge or coordinate correction was invented.
* Eighteen old Jaipur image overrides and required Udaipur/Varanasi media are unresolved. Source gallery rows remain untouched in SQLite; the output copy is sanitized.
* Source preflight prevents corrupt input replacement, but sync is not a filesystem transaction with rollback across all city files after an unexpected disk or copy failure. The dialog reports failure and attempts to reopen the city.
* Corrupt and orphaned decisions remain preserved and block certification with explanations; sync does not delete human evidence to make a gate pass. Administrative repair beyond source refresh may require a reviewed curation change.
* Web remains an inspection preview with memory-only curation; local sync, image import and certified builds require desktop.
* No production publication, commit or pull request was performed. Existing curator work was preserved; source SQLite stayed unchanged; no remote POI enrichment was added.

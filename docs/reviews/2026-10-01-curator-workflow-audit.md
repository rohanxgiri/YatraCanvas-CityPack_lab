# Real-data curator workflow audit — 2026-10-01

This audit used the running Windows desktop application and the synchronized DataFactory v3 packs. It resulted in targeted application fixes and durable, real curator decisions. **The complete contributor acceptance criterion is not yet proven. All three real packs remain BLOCKED.** Successful certification was verified with controlled test fixtures, not by inventing fifty approvals for a real city.

## 1. Real Data Loaded

Counts were read from SQLite opened with `mode=ro` and the actual JSON manifests. No count is hardcoded in the application.

| City | Published | Raw candidates | Selectable candidates | Conflicting ID groups | Withheld records | Media records |
|---|---:|---:|---:|---:|---:|---:|
| Jaipur | 684 | 893 | 864 | 13 | 29 | 73 |
| Udaipur | 324 | 322 | 316 | 3 | 6 | 77 |
| Varanasi | 348 | 372 | 365 | 3 | 7 | 151 |

All three packs are v3/schema 3.0. The registry versions match. Source databases, review manifests, release metadata and image manifests exist. SQLite integrity checks return `ok`; existing manifest-checksummed files match their expected hashes. Source SQLite assets were not modified.

All primary POI images resolve. Gallery references do not: Jaipur has 60 missing image/thumbnail paths, Udaipur 76, Varanasi 128, corresponding to 30/38/64 absent gallery image files and their thumbnails. No bundled media record has a missing/unknown license. The machine-readable inventory is `2026-10-01-pack-inventory.json` beside this report.

## 2. Workflow Tested

The live desktop path was pack selection → Jaipur workbench Home → Inbox → candidate detail → decision → Inbox → Manual QA → Release. The current UI uses Home/Fix/Inbox/QA/Places/Release rather than the older screen names in the request.

On Jaipur, the audit exercised All/High/Medium/Low, the contradictory-place-type reason filter, clearing filters, local search `sch`, scrolling, source detail inspection, Keep, Exclude, Needs Research, Edit, explicit one-record bulk exclusion with confirmation, and QA defect reporting. Grouped review was exercised by reason and priority on Jaipur and category on Varanasi. The reason grouping shows 862 secondary commercial candidates and two conflicting-place-type candidates, using the full filtered collection.

Real actions saved:

| Candidate | Action | Evidence/intent |
|---|---|---|
| Handicraft Jaipur | Keep | Bundled craft classification, website and phone; kept as a recommended craft venue |
| Prince School Hostel | Exclude | School-associated hostel; source did not establish ordinary traveller accommodation |
| Prince Residential School | Exclude through explicit bulk selection | School-associated record; one selected record confirmed in the exclusion dialog |
| Nice Cafe (it's the name) | Needs Research | Cafe amenity conflicts with house building semantics |
| Natawat Ji Ka Mandir , Jaipur | Edit, then Needs Research | Removed the space before the comma; identity conflict remains unresolved |

For Natawat, the source name stayed unchanged and the effective human override became `Natawat Ji Ka Mandir, Jaipur`. The editor initially supplied a misleading default evidence label; the saved evidence metadata was subsequently corrected to explicitly describe the typography-only correction. This was an audit metadata correction, not verification of the temple's identity.

Udaipur and Varanasi were opened through the actual pack picker. Their Inbox, source details, QA and Release screens loaded. Gothwal Art (Udaipur) and Chaudhary Textiles (Varanasi) were marked Needs Research. Varanasi's Needs Research filter returned its one saved candidate; reason and category grouping retained that count. Udaipur's blocked report export was actually performed and inspected.

## 3. UX Problems Found

- Duplicate canonical IDs could share a decision despite representing ambiguous candidates.
- Filter labels were hard to read and controls overflowed the narrower desktop window.
- Group counts and content were restricted to the first page rather than all matches.
- Subcategory, missing-field and research status filtering were incomplete.
- The candidate editor was not connected to the established override workflow.
- Source explanations and long descriptions made inspection unnecessarily technical.
- Inbox decisions did not consistently feed the effective curation/quality view.
- A real QA defect write exposed a dynamic getter crash when legacy and curator review models were mixed; the screen continued showing zero reviews.
- Blocked report export failed because the curation summary was not JSON serializable; the success dialog also implied certification for a blocked pack.
- Upstream category rejection counts polluted the published-pack quality score.
- Reopening could reuse a stale runtime database when a refreshed source file had the same size.
- Baseline image synchronization removed extra curated files.

## 4. UX Fixes Made

Conflicting IDs are now withheld with a recovery warning and a critical release blocker. Filters use readable colors, wrap on narrow layouts, expose subcategory/missing-field/research status, and clear the search, tabs, pagination and selection together. Grouping runs over every filtered match; expanded groups load thirty more records at a time.

The detail panel explains house-versus-cafe/temple conflicts in ordinary language, permits expanding technical tags and long descriptions, and saves edits through existing overrides. Bulk Keep/Exclude acts only on explicit selections and summarizes count/reasons before applying changes; heterogeneous selections receive a warning.

Saved Inbox decisions produce an effective in-memory curation view while the source pack remains immutable. Certification applies them to an output copy and retains candidate source identities. Semantic source changes reopen decisions. Runtime database copies refresh on reopen. Image sync merges directories instead of deleting curated extras.

Manual QA now reads both record types safely, deduplicates reviewed place IDs and preserves zero/partial lifecycle states. Quality scoring measures published category completeness rather than upstream rejected candidates. The release UI now shows actual blocker/workload counts, database/schema/media license checks, QA status, a direct Inbox link and accurate blocked-report export wording. Exported release evidence includes validation, warnings and review state.

README and the Contributor Guide explain the seven-step curation flow, source immutability, evidence, what to commit and what to leave out. They do not require a personal absolute path.

## 5. Review Inbox Validation

| Jaipur measure | Actual value |
|---|---:|
| Raw HIGH | 892 |
| Raw MEDIUM | 1 |
| Raw LOW | 0 |
| Selectable HIGH | 863 |
| Selectable MEDIUM | 1 |
| Selectable LOW | 0 |
| Reviewed candidates with saved Inbox decisions | 5 |
| Resolved decisions | 3 |
| Untouched/unreviewed selectable candidates | 859 |
| Needs Research | 2 |
| Total unresolved | 861 |
| Unresolved HIGH | 860 |

Twenty real HIGH records and the only available MEDIUM were inspected in the artifact sample. There are no LOW records to sample. Almost all HIGH records carry `SECONDARY_COMMERCIAL_REQUIRES_AUDIT`; this is poor upstream prioritization, not evidence that all are critical. The lab retains the supplied priority rather than silently relabeling it.

The actual Medium tab displayed Natawat, Low displayed an empty state, and clearing filters restored 864 matches. After restart, Handicraft still displayed KEPT and the header still displayed three resolved/861 unresolved.

## 6. Persistence Test

The normal sync command was executed against the actual sibling DataFactory repository after real reviews:

```powershell
python tools/sync_city_packs.py --cities Jaipur
```

All five Jaipur Inbox decision files had identical SHA-256 values before and after the final sync. No duplicate decision files appeared. One concrete example:

```text
yc_in_rj_jaipur_handicraft_jaipur.json
before: 58592515D02B7F4BFA04684C235CB0D01924D1880835F042859490C6F8A16721
after:  58592515D02B7F4BFA04684C235CB0D01924D1880835F042859490C6F8A16721
verdict: approved (Keep)
```

The source refresh retained registry v3, 684 published places and 893 raw candidates. A full app restart and reopening Jaipur confirmed Handicraft's KEPT state, three resolved decisions, 861 unresolved, and the separately saved QA review at 1/50. The original source database remains unchanged by curation.

## 7. Changed-Since-Review Test

Controlled fixtures derived from a real Jaipur candidate changed classification, coordinates, source identity, Wikidata, image evidence, confidence, missing fields and critical OSM tags. Each material change marked the decision Changed since review and made `isResolved` false. Existing reason/action and score-shift behavior is retained.

The final policy compares name/category/subcategory/tier, relevant semantic OSM tags, normalized external IDs, Wikidata/image evidence, reason/action, missing-field set in either direction, score/confidence shifts greater than 0.05 and coordinates differing by more than 0.0005 degrees. Timestamp changes, collection ordering and tiny coordinate noise do not reopen review. This coordinate tolerance is angular, not an exact distance measurement.

These were controlled automated fixtures; the synchronized manifests were not edited to manufacture a live source change. The Python certified-pack builder independently rejects stale semantic decisions even if the desktop app was not reopened.

## 8. Release Gate

**Actual blocked example:** Jaipur v3 shows DQ 58/100, travel readiness 87/100 and Manual QA `IN_PROGRESS (1/50)`. Four critical blockers remain: conflicting candidate identities, one core destination outside bounds, incomplete QA and DQ below 70. A high travel score does not override them. Certify is disabled, with blocked-report export available.

Udaipur's actual report export produced the existing `release.json`, `quality_report.json` and `release_report.md`. Inspected release evidence identified Udaipur/v3, `not_certified`, `release_gate_status: BLOCKED`, `certified_at: null`, `manual_qa_passed: false` and 0/50 reviews. The corrected dialog explicitly called this a blocked release report.

**Successful controlled example:** the quality-engine READY fixture passes the gates; the Python READY build fixture creates the separate certified output copy, applies curation, regenerates artifacts, writes `status: certified` and preserves the source database hash. Blocked and REVIEW_REQUIRED evidence are rejected before production output. These are successful automated certification examples, not a real-city curator certification.

Critical failures cover integrity/schema, identity ambiguity, core geography, incomplete/uncertain/excess-defect QA and required media license metadata. Optional minor-place photo/hours/description gaps remain warnings. Optional warning count alone does not block READY. Required artifacts and physical media paths receive further validation in the certified-pack builder.

## 9. Manual QA

Inbox addresses known candidate uncertainty; Manual QA samples published records. The UI now states that distinction. Actual Jaipur QA: inspected Jhalana–Amagarh Leopard Conservation Reserve, reported Missing Expected Information and saved a defect. Its durable review/issue files were created. After fixing the mixed-model crash and avoiding duplicate legacy counting, the real app correctly shows **1/50**, not two reviews or a pass.

The reproducible sample contains sixty unique places; fifty completed reviews remains the minimum gate. Measured tier distributions:

| City | Core | Recommended | Discovery | Support | Categories |
|---|---:|---:|---:|---:|---:|
| Jaipur | 29 | 19 | 4 | 8 | 13 |
| Udaipur | 33 | 9 | 8 | 10 | 11 |
| Varanasi | 40 | 8 | 5 | 7 | 11 |

Jaipur includes heritage, parks, religious sites, museums, arts/culture, viewpoints, hotels, food, cafe, shopping, nature, experiences and transport. Deterministic repeated generation returns the same ordered sample. Udaipur and Varanasi remain `NOT_STARTED (0/50)`. No review approvals were fabricated.

## 10. Cross-City Results

| City | Live workflow observed | Saved Inbox state | Release |
|---|---|---|---|
| Jaipur | Keep, Exclude, Edit, Research, bulk confirmation, filters/grouping, QA defect, restart after real sync | Five decisions; three resolved; two research | BLOCKED; final live DQ 58/TR 87; QA 1/50 |
| Udaipur | Pack navigation, Inbox detail/research, QA image preview, Release, successful blocked report export | Gothwal Art research; zero resolved; 316 unresolved | BLOCKED; identity collisions and QA 0/50 |
| Varanasi | Pack navigation, Inbox detail/research, research filter, reason/category grouping, QA, Release | Chaudhary Textiles research; zero resolved; 365 unresolved | BLOCKED; final live DQ 73/TR 79; QA 0/50 |

Udaipur's displayed score was DQ 72/TR 80 before the final published-category scoring correction; a final post-correction Udaipur score was not captured. Varanasi has 117 core destinations; 35 lack hero images and 114 lack schedules. Its final live gate correctly retained blocking QA/identity failures despite DQ exceeding 70.

Local artifact name searches returned Jaipur: Lassiwala 0, Mandir 17, Cafe 16, Johari 0; Varanasi: Ghat 0, Temple 11, Cafe 20. These are Inbox-manifest searches, not counts of published attractions. All requested search strings were not entered through the native UI. The live `sch` search returned four sensible Jaipur candidates and supported the school-hostel inspection.

## 11. Tests

Final executed results:

```text
flutter analyze --no-pub
No issues found! (5.9 seconds); exit 0

flutter test --no-pub
85 tests; All tests passed!; exit 0

python -m unittest tools.tests.test_certification
10 tests; OK; exit 0

git diff --check
exit 0; only normal Windows LF/CRLF conversion notices
```

Regression coverage includes real candidate persistence, identity collisions/schema mismatch, semantic changes/noise, three-city sample diversity, mixed QA models, JSON-serializable statistics and certified-output source preservation. Tests complement the live observations above; they do not replace missing native verification.

## 12. Remaining Limitations

1. DataFactory must repair conflicting canonical IDs before any real certification. Jaipur also needs its core geographic failure and low DQ addressed.
2. The real fifty-item QA requirement is incomplete in every city. A full successful real-city certification was therefore neither possible nor claimed.
3. The desktop certification action exports evidence; producing the certified SQLite output still uses the existing release-manager command. Baseline sync is also a command. The requested fully graphical, non-technical SYNC → CERTIFY acceptance criterion is not yet met.
4. All requested native search strings, combined category/subcategory/tier/missing-field combinations, expanded pagination, error/recovery states and image approval/provenance fields were not exhaustively exercised. These remain specific verification gaps.
5. Missing gallery paths remain upstream asset defects. The native media-license check does not establish that every referenced media file exists; the output builder validates file paths separately.
6. Existing image-import documentation identifies author/source-page/license-URL metadata gaps; a complete live licensed-image approval workflow was not established in this pass.
7. Priority assignment remains overwhelmingly HIGH for generic commercial candidates. No new priority score or silent relabeling was introduced.
8. UI scrolling/navigation appeared usable during the exercised flow, but no frame-time or input-latency benchmark was captured. No fresh laptop clone/setup was performed; developer-machine-specific documentation paths were checked rather than installation independently reproduced.
9. Image sync preserves extra curated files but may still overwrite a curated image if it shares an exact upstream path. Published-category completeness checks nonempty/known-value markers, not the entire taxonomy whitelist.
10. No production publication, commit or PR was performed. The source pack was kept immutable and no remote POI enrichment was added.

The remaining gaps are explicit follow-up work, not implied passing checks. The audit provides real evidence of safe decisions, source preservation, honest blockers and targeted fixes, while retaining the distinction between passing tests and complete contributor acceptance.

# CityPack Lab Release Manager Guide

This guide is for maintainers who import DataFactory baselines, assess merged curation, certify a City Pack, and explicitly publish it. Ordinary contributors should use the [Contributor Guide](CITY_LAB_CONTRIBUTOR_GUIDE.md) and stop at a Pull Request.

## 1. System and responsibility boundary

```text
Contributor Pull Request
        ↓ review and merge into CityPack Lab main
Release Gate evaluation
        ↓ READY evidence
Local certification
        ↓ validated artifact and checksums
Explicit publication
        ├── durable curation → DataFactory
        └── certified pack → YatraCanvas traveller app
```

Data ownership is deliberately separated:

| Layer | Source of truth | Typical contents |
|---|---|---|
| Baseline generated data | DataFactory release | `yatracanvas.db`, manifests, city metadata, provider-derived images |
| Human curation | CityPack Lab | overrides, additions, exclusions, reviews, issues, curated media metadata |
| Published app pack | Certified output | reconciled database, images, manifest, release descriptor, checksums |

Never make human corrections directly in the baseline `yatracanvas.db`. Certification copies the baseline to staging and applies curation to the copy.

## 2. When all three repositories are required

- **CityPack Lab only:** reviewing and merging contributor curation; running the app, summary, Flutter tests, analyzer, and certification-core tests; creating a local certified artifact when Release Gate evidence is available.
- **CityPack Lab + DataFactory:** listing or synchronizing newly generated baseline packs.
- **All three repositories:** production publication. The exporter writes durable curation to DataFactory and the certified artifact to the traveller app.

The publication code searches for directories named exactly:

```text
YatraCanvas-DataFactory
YatraCanvas
```

It checks the current working directory's parent, the CityPack Lab repository's parent, and `$HOME/Documents`. A conventional layout is:

```text
Documents/
├── YatraCanvas-DataFactory/
├── YatraCanvas-CityPack-Lab/   # the local folder name may differ
└── YatraCanvas/
```

The GitHub repository is named `YatraCanvas-CityPack_lab`, but the publication code does not depend on the Lab checkout's folder name. It **does** require the traveller-app checkout to be locally named `YatraCanvas`; a folder named `yatra_canvas` is not discovered automatically.

## 3. Release manager prerequisites

- Git;
- Flutter stable with Dart 3.13 or newer and Windows desktop support;
- Python 3.12 or newer;
- a clean, reviewed CityPack Lab `main` branch;
- DataFactory only for baseline sync or publication;
- the `YatraCanvas` checkout only for publication or traveller-app testing.

Before release work:

```powershell
git checkout main
git pull origin main
git status
flutter pub get
```

Do not proceed with unexplained local changes.

## 4. Baseline synchronization

`tools/sync_city_packs.py` is a release-management tool, not a normal curation command. It discovers DataFactory releases while ignoring paths under `quarantine`.

List available DataFactory releases:

```powershell
python tools/sync_city_packs.py --list
```

Synchronize selected baselines:

```powershell
python tools/sync_city_packs.py --cities "Jaipur,Manali"
```

The tool copies available deployment artifacts such as:

```text
yatracanvas.db
manifest.json
city.json
checksums.json
image_manifest.json or images_manifest.json
license_manifest.json
source_manifest.json
images/
```

It verifies copied file hashes, writes `lab_sync_receipt.json`, regenerates `city_packs_index.json`, and rewrites the `pubspec.yaml` asset list.

### Why sync must be deliberate

For each selected city, synchronization overwrites matching deployment files and, when DataFactory has an `images/` directory, deletes and replaces the destination city's entire `images/` directory. It does not intentionally delete `curation/`, but curated image bytes also live under the replaced `images/` tree. Therefore:

1. never sync over uncommitted work;
2. review and preserve merged curation and curated images first;
3. run sync on a dedicated branch;
4. inspect `git status` and `git diff` afterward;
5. reconcile any curated-media changes before merge.

Do not tell an ordinary contributor to run sync when a committed pack is merely missing from an incomplete clone.

## 5. Pre-certification review

After contributor PRs are reviewed and merged:

```powershell
.\citylab.ps1 summary -City jaipur
.\citylab.ps1 test
flutter analyze
python -m unittest tools.tests.test_certification -v
```

Also inspect:

- open curation issues;
- overrides, additions, and exclusions;
- all curated image bytes and media JSON;
- image source, source page, author/creator, licence, licence URL, contributor, dimensions, and hashes;
- Manual QA count and defect rate;
- Data Quality and Travel Readiness independently;
- hard Release Gate blockers.

The current desktop image dialog does not collect author and writes an empty `author` field. It also permits an empty `sourcePage`, and the **Contributor owned** choice supplies an empty `licenseUrl`. Certification requires all of these media fields to be non-empty. Resolve each implementation/metadata gap from verified evidence before certification; never invent attribution.

## 6. Create Release Gate evidence

Run the Windows app:

```powershell
.\citylab.ps1 start -Target windows
```

Select the city and open **Release**. A production artifact requires:

- Release Gate status `READY`;
- a sufficient Manual QA sample (at least the configured 50 reviews);
- matching city ID and pack version in the evidence.

Use the Release screen's export action. On desktop, City Lab writes:

```text
<Application Documents>/qa_exports/release_<city>.json
<Application Documents>/qa_exports/quality_report_<city>.json
<Application Documents>/qa_exports/release_report_<city>.md
```

Use the exact path shown by the app or locate the files in the platform application-documents directory. The Python certification command consumes `release_<city>.json`.

The screen can also produce a `not_certified` report when gates have not passed. That file is useful for diagnosis but is rejected for certified production output.

## 7. Build a local certified artifact

Use a new output directory; the exporter refuses to overwrite an existing directory.

```powershell
.\citylab.ps1 export `
  -City jaipur `
  -ReleaseEvidence "C:\path\to\qa_exports\release_jaipur.json" `
  -OutputDir "releases\jaipur\2026-09-29-certified"
```

Equivalent Python command:

```powershell
python tools/export_certified_pack.py `
  --city jaipur `
  --release-evidence "C:\path\to\qa_exports\release_jaipur.json" `
  --output-dir "releases\jaipur\2026-09-29-certified"
```

Certification is fail-closed. It validates Release Gate evidence, curation references and verification, SQLite integrity, media paths and attribution, the final database, manifests, counts, and hashes. It stages work separately and leaves the source `yatracanvas.db` unchanged.

A successful artifact includes:

```text
release.json
manifest.json
image_manifest.json
checksums.json
yatracanvas.db
images/<place_id>/primary.webp
images/<place_id>/thumbnail.webp
```

Inspect the console reconciliation counts and compare the final database SHA-256 with `release.json` and `checksums.json`.

## 8. Developer-only diagnostic export

When a maintainer needs to inspect reconciliation before the pack is `READY`, create a clearly non-certified local artifact:

```powershell
.\citylab.ps1 export `
  -City jaipur `
  -ForceDevExport `
  -OutputDir "scratch\jaipur-dev"
```

This bypasses only release eligibility. Other curation, database, path, and media validation still runs. The result is marked `non_certified`.

`-ForceDevExport` cannot be combined with `-Publish`. A development artifact cannot be published.

## 9. Publish explicitly

Only publish after reviewing a successful local certification and confirming the two sibling targets are correct.

```powershell
.\citylab.ps1 export `
  -City jaipur `
  -ReleaseEvidence "C:\path\to\qa_exports\release_jaipur.json" `
  -OutputDir "releases\jaipur\2026-09-29-publish" `
  -Publish
```

Publication prepares both targets before replacing either:

- `YatraCanvas-DataFactory/data/curated/<city>/` receives the curation tree plus every referenced curated image;
- `YatraCanvas/assets/city_packs/<city>/` receives the complete certified artifact.

Existing target directories are moved to temporary backups, staged directories are swapped into place, and a failure triggers rollback of installed targets. Cross-repository publication is still not a single operating-system transaction, so read the receipts and inspect both repositories after success.

## 10. Post-publication verification

In each target repository:

```powershell
git status
git diff
```

Verify:

- the DataFactory curation bundle contains the expected JSON and curated images;
- the traveller-app pack contains `release.json`, manifests, checksums, database, and images;
- `release.json` says `certified` and records the expected city, version, scores, QA result, and database hash;
- every `checksums.json` entry matches the published file;
- the traveller app can load the pack using its own documented test workflow.

Publication changes sibling working trees; it does not commit or push those changes for you.

## 11. Failure behavior

On certification failure, the command prints numbered blockers, exits non-zero, removes its staging directory, and prints that the pack was not published. Common blockers include:

- Release Gate status is not `READY`;
- Manual QA is incomplete;
- evidence city or pack version does not match;
- an override is unverified or references an unknown place;
- curated media is missing a required file or attribution field;
- a media path escapes the pack;
- SQLite integrity, counts, or hashes fail;
- the output directory already exists.

Correct the underlying data or evidence and retry with a new output directory. Do not weaken gates, fabricate metadata, or edit the baseline database.

## 12. Release checklist

```text
[ ] Contributor PRs reviewed and merged
[ ] CityPack Lab main is current and clean
[ ] Curation summary reviewed
[ ] Flutter tests pass
[ ] Flutter analyzer passes
[ ] Certification-core tests pass
[ ] Manual QA sample is sufficient
[ ] Release Gate is READY
[ ] Curated-image attribution is complete and verified
[ ] READY release evidence exported
[ ] Local certified artifact built and inspected
[ ] Checksums and reconciliation counts verified
[ ] Sibling repository paths confirmed
[ ] Explicit publication completed
[ ] DataFactory and YatraCanvas diffs inspected
[ ] Traveller-app loading/testing completed
```

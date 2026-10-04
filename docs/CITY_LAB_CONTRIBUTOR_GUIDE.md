# CityPack Lab Contributor Guide

This is the detailed guide for curators working on City Packs already committed to this repository. Your workflow ends with a branch and Pull Request:

```text
make evidence-backed corrections
        ↓
run Manual QA and validation
        ↓
inspect and commit relevant files
        ↓
push branch
        ↓
open Pull Request
```

You do **not** need DataFactory or the YatraCanvas traveller-app repository for this workflow. Certification and publication are covered separately in the [Release Manager Guide](RELEASE_MANAGER_GUIDE.md).

## 1. First-time setup

### Curating a City

1. Already committed packs need no DataFactory checkout. To refresh them, open **Sync Latest City Packs** in the workbench toolbar. Enter the DataFactory repository location, choose **Verify**, select cities, and choose **Sync**. The location is saved locally, outside Git. DataFactory need not be a sibling checkout.
2. Run `.\citylab.ps1 start -Target windows`, select the city, and open its workbench.
3. Start with **Release → View Blockers**, then **Inbox → Start Here**, which shows unresolved BLOCKING and HIGH records. Priority measures curator impact independently of confidence. Medium and Low remain available. **Identity Conflicts** shows colliding source records and records merge, separate, exclude or research decisions. Published collisions and repeated source identities require upstream repair. KEEP and EXCLUDE remain separate inclusion decisions after an identity resolution.
4. Use **Edit details with a human override** for evidence backed corrections. The source name and human override remain separate. Never edit SQLite or the review manifest yourself.
5. Open **QA** to spot check published places. Inspect the image, description, coordinates, hours and source information before PASS, ISSUE or Needs Research. P means Pass, I opens an Issue, and J/K or arrows move through the queue when you are not entering text. Skip does not count as reviewed. Progress and defects persist. **Open Place** and **Fix Now** connect findings to curation; **Recheck reviewed places** lets you inspect a correction again. Complete at least 50 distinct reviews. Finishing the sample does not dismiss defects or research.
6. Open **Release**, refresh validation, inspect blockers and warnings, and export the report. A blocked report is evidence of unfinished work. Missing primary media, invalid replacement image evidence and unsafe identity decisions prevent certification. Sync removes unavailable optional gallery entries and keeps those removals in its validation receipt.
7. When validation is READY, choose **Build Certified Pack** in Release. The canonical Python builder validates a separate output copy and writes its integrity and certification evidence. It applies curated changes without altering the source SQLite. The result includes its output location and expandable technical logs. Publishing remains a separate explicit action. Inspect and commit the curation artifacts through a Pull Request.

The normal curator flow is graphical after initial setup. Python must be available locally for sync and certified builds. In **Local tools settings**, you can configure its executable and the City Lab checkout when necessary. Launch the desktop app through the checkout's start script so its working directory points to the same checkout. Changing the tools setting alone does not relocate the active curation workspace.

Commit relevant `assets/city_packs/<city>/curation/inbox_decisions/*.json`, overrides, additions, exclusions, reviews, issues, media metadata, and the corresponding imported image files. Include `pubspec.yaml` only when its asset registrations intentionally changed. Sync preserves Inbox decisions and extra curated media files; inspect refreshed baseline files separately.

Do not commit `build/`, `.dart_tool/`, temporary audit output, application support database copies, or generated QA exports by default. Release evidence belongs in a reviewed release submission when intentionally requested. The pack registry's source path is a sync receipt, not a required contributor path.

Install:

- Git;
- Flutter stable with Dart 3.13 or newer;
- the Windows desktop development components reported by `flutter doctor`;
- Python 3.12 or newer for the curation summary command.

Clone the repository and install dependencies:

```powershell
git clone https://github.com/rohanxgiri/YatraCanvas-CityPack_lab.git
cd YatraCanvas-CityPack_lab

flutter doctor
flutter pub get
.\citylab.ps1 setup
```

The setup script checks Git, Flutter, available Flutter devices, packages, and `assets/city_packs/`. The committed City Packs are sufficient for ordinary curation.

Create a focused branch:

```powershell
git checkout main
git pull origin main
git checkout -b curate/jaipur-yourname
```

## 2. Run the Windows desktop app

```powershell
.\citylab.ps1 start -Target windows
```

Windows desktop is the working curation environment. From the repository working directory, curation is written to Git-trackable files in `assets/city_packs/<city>/curation/`.

### Chrome limitations

```powershell
.\citylab.ps1 start -Target chrome
```

Chrome is useful for review and UI development, but it is not the normal authoring environment:

- curation changes are stored only in browser memory;
- browser changes do not become Git-tracked JSON files;
- curated image import is disabled because it must write local files;
- exported reports are represented in browser memory rather than written to the desktop export directory.

Do not complete work in Chrome and assume it is ready to commit.

## 3. Select a city

On the City Pack selection screen, choose the city you were assigned. Confirm the pack name, version, place count, and integrity information before editing.

The main navigation contains:

- **Home** — scores, progress, and blockers;
- **Fix** — grouped problems and focused correction tools;
- **Review** — the stratified Manual QA queue;
- **Places** — searchable place inventory, add, edit, and exclude actions;
- **Release** — gate status and evidence export for release managers;
- **Advanced** — diagnostics shown only in admin mode.

Normal contributors use Home, Fix, Review, and Places. A Release status is useful context, but contributors do not certify or publish.

## 4. Understand where changes go

City Lab keeps the generated database read-only and writes one small JSON record per entity:

```text
assets/city_packs/<city>/curation/
├── overrides/    corrections to existing places
├── additions/    manually added places
├── exclusions/   reversible exclusions
├── reviews/      Manual QA decisions
├── issues/       defects requiring follow-up
└── media/        curated-image metadata
```

**DO NOT MANUALLY EDIT `yatracanvas.db`.** It is the generated baseline. Direct edits cannot be reviewed or reapplied reliably and may be overwritten by regeneration.

## 5. Use Fix Center

Open the **Fix** tab and choose a problem group, such as missing photos, missing opening hours, coordinate problems, or category problems.

For each item:

1. Inspect the place and the reported problem.
2. Open the relevant correction tool.
3. Enter only values supported by reliable evidence.
4. Add the evidence/source requested by the form.
5. Save the correction, or choose **Flag for later** when the answer is uncertain.

Saving creates or updates an override or issue record; it does not change the baseline database. Scores and task lists are reevaluated after curation changes.

## 6. Use Places CMS

Open the **Places** tab to search the city inventory. The list marks records such as curated, manual additions, excluded, incomplete, or ready.

Open a place to inspect and edit supported details. The place editor includes name, local-script name, tier, description, website, phone, and evidence. Focused correction dialogs exposed by Fix/Review handle fields such as hours, coordinates, category, and images.

### Correct opening hours

1. Open the place from a missing-hours Fix item or the review correction flow.
2. Enter the verified schedule in the supported editor.
3. Cite an official page, on-site evidence, or another reliable source.
4. Save and confirm the corresponding override appears in Git status.

Do not infer hours from a similar attraction or an old search snippet.

### Correct coordinates

1. Verify the correct destination, not merely a similarly named business.
2. Use WGS84 latitude and longitude.
3. Confirm the point is on the actual attraction and within the correct city context.
4. Provide the evidence requested by the correction flow and save.

Core destinations outside the city bounds are hard release blockers, so uncertain coordinates should be flagged instead of guessed.

### Correct categories and tier

Use the category/tier controls offered by the correction flow. Choose the category that describes the visitor experience, and only mark a place as a Core Destination when the evidence and project policy support it. Save the change with evidence.

## 7. Add a missing place

In **Places**, select **+ Add Place**. The wizard currently asks for:

1. identity — English name, optional local name, category, and tier;
2. location — WGS84 latitude/longitude and address;
3. details — description, opening hours, and required evidence/source link;
4. media — an image path or URL field;
5. review — a final summary before submission.

Check spelling, location, category, and evidence before submitting. The app writes the new record to:

```text
assets/city_packs/<city>/curation/additions/<place_id>.json
```

Use the dedicated desktop image import workflow for local image files and attribution; do not invent an image path.

## 8. Exclude a place

Exclude a place only when it should not ship—for example, a duplicate, permanently closed destination, restricted facility, or irrelevant record.

1. Open the place in **Places**.
2. choose **Exclude Place**;
3. select the mandatory reason;
4. add useful context;
5. confirm the exclusion.

The app writes a reversible record to `curation/exclusions/`. It does not delete the source row from `yatracanvas.db`.

## 9. Replace or import an image

Use Windows desktop and open the photo action from Fix Center or the place workflow.

1. Choose a JPG, PNG, or WebP file no larger than 25 MB.
2. Use an image at least 640 × 480 pixels.
3. Enter a real source and a verifiable source page/evidence URL. Although the dialog labels the page optional for own work, certification currently requires a non-empty value.
4. Select the correct licence and preserve its licence URL.
5. Preserve the creator/author information from the source for review.
6. Import the image.

The importer creates:

```text
assets/city_packs/<city>/images/<place_id>/primary.webp
assets/city_packs/<city>/images/<place_id>/thumbnail.webp
assets/city_packs/<city>/curation/media/<place_id>.json
```

It creates a primary WebP with a maximum long edge of 1600 px and a 480 px thumbnail. It may also add the image directory to `pubspec.yaml`.

The current dialog has three certification mismatches: it has no author input and writes `author` empty, it permits an empty `sourcePage`, and its **Contributor owned** choice has an empty `licenseUrl`. Certified export requires all three fields to be non-empty. Mention the verified creator and evidence in the PR and flag any metadata gap for the release manager—never fabricate a name, page, or URL.

If the source, author, or licence cannot be verified, do not use the image.

## 10. Complete Manual QA

Open **Review**. City Lab builds a stratified sample queue rather than treating a handful of arbitrary reviews as sufficient.

For each place:

- inspect its name, image, category, coordinates, and other visible details;
- choose **Yes, Verify Correct** only when the record is sound;
- choose **Something is wrong** to fix immediately, flag a defect, or skip when appropriate.

Manual QA follows a strict lifecycle:

- zero reviews: `NOT_STARTED`;
- fewer than the configured 50 reviews: `IN_PROGRESS (X/50)`;
- at least 50 reviews: sufficient sample, subject to the configured defect threshold.

An incomplete 50-item sample is a release blocker even if the numerical scores are high. Review records are stored in `curation/reviews/`.

## 11. Flag unresolved issues

Use **Flag for later** or **Flag Defect for Review** when evidence is missing, conflicting, or requires local knowledge. Add a useful note explaining what is wrong and what was checked.

Issues are stored in `curation/issues/`. An honest unresolved issue is preferable to fabricated data.

## 12. Generate a curation summary

From the repository root:

```powershell
.\citylab.ps1 summary -City jaipur
```

The command reads the Git-tracked curation directories, prints a short result, and writes `curation_summary.md`. Inspect the generated report. It is not automatically required in the commit; use its contents in the PR unless the reviewer asks for the file.

## 13. Test

```powershell
.\citylab.ps1 test
flutter analyze
```

`citylab.ps1 test` runs the full Flutter test suite. If a test fails, investigate whether your data or application behavior caused it. Do not delete or weaken a failing test just to make the command green.

## 14. Inspect and commit

First inspect everything:

```powershell
git status
git diff
```

Stage only the applicable city curation:

```powershell
git add assets/city_packs/jaipur/curation/
```

For image work, stage only the affected place directories and the relevant asset registration:

```powershell
git add assets/city_packs/jaipur/images/<place_id>/
git add pubspec.yaml
```

Review the staged diff:

```powershell
git status
git diff --staged
```

Then commit with a plain outcome-focused message:

```powershell
git commit -m "Curate Jaipur opening hours"
```

Do not blindly run `git add .`. Shared files such as `pubspec.yaml` may contain unrelated work.

## 15. Push and open a Pull Request

```powershell
git push -u origin curate/jaipur-yourname
```

Open a Pull Request into `main`. Complete the template with the city, counts, sources, Manual QA progress, image details, validation results, and unresolved issues.

Contributors normally **do not push directly to `main`** and do **not** run `.\citylab.ps1 export`, `tools/export_certified_pack.py`, or production publication.

## 16. Update your branch later

Save or commit your work, then:

```powershell
git checkout curate/jaipur-yourname
git fetch origin
git merge origin/main
```

Resolve conflicts by understanding and preserving both valid changes. For JSON records, compare the evidence and intended value. For images and `pubspec.yaml`, inspect both sides. Run the summary, tests, and analyzer again after the merge.

Do not use `git reset --hard`, force-push, or discard another contributor's work as routine conflict handling.

## 17. Troubleshooting

### `flutter` is not recognized

Install Flutter and add its `bin` directory to PATH. Open a new PowerShell window and run:

```powershell
flutter doctor
```

### Windows desktop target is missing

```powershell
flutter doctor
flutter devices
```

Install or enable the Windows desktop prerequisites reported by Flutter, then rerun the commands.

### `python` is not recognized

Install Python 3.12 or newer and enable its PATH option. Reopen PowerShell and run `python --version`.

### Flutter dependencies fail

```powershell
flutter pub get
```

Read the first error and resolve the SDK or network problem; do not edit dependency versions casually.

### The app has no City Packs

Confirm that `assets/city_packs/` contains the committed city directories and that each selected pack has `yatracanvas.db` and `manifest.json`. Check that the clone is complete, then ask a maintainer if assets are missing. Ordinary contributors should not install DataFactory or run baseline sync merely to repair an incomplete clone.

### Git push is rejected

Do not force-push. Update your feature branch from `origin/main`:

```powershell
git fetch origin
git merge origin/main
```

Resolve any conflicts, rerun validation, commit the merge if needed, and push again. If Git says the remote feature branch itself has new commits, coordinate with its other contributor before merging or rebasing it.

## 18. Do not do this

- Do not manually edit `yatracanvas.db`.
- Do not fabricate opening hours, coordinates, photos, categories, or sources.
- Do not use unverifiable images or attribution.
- Do not push directly to `main`.
- Do not production-publish as a normal contributor.
- Do not overwrite another contributor's curation to resolve a conflict.
- Do not run `tools/sync_city_packs.py` over important uncommitted work.
- Do not commit unrelated build files or generated output.

## 19. Getting help

Open a GitHub issue or ask in the Pull Request. Include the city, place ID, exact screen/action, error text, and the evidence you checked. Never hide uncertainty—record it so a reviewer can help.


## Bundled city-data loop — 2026-10-04

`[IMPLEMENTED]` See [the city-data loop](CITY_DATA_DEV_LOOP.md) for the new immutable app export, base-bound human repair patch and safe sync commands. Existing strict certification/provider architecture remains intact. `[PARTIAL]` Physical-phone acceptance remains unverified. No production migration or paid provider call is part of this loop.

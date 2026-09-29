# Contributing to YatraCanvas CityPack Lab

Thank you for helping improve YatraCanvas city data. This guide covers Git and GitHub collaboration. For the app itself, use the [hands-on contributor guide](docs/CITY_LAB_CONTRIBUTOR_GUIDE.md).

## Roles

- **Curator:** makes evidence-backed corrections, imports licensed images, adds or excludes places, records issues, and completes Manual QA.
- **Reviewer:** checks the proposed files, sources, attribution, QA progress, and validation results.
- **Release manager:** certifies and publishes an approved pack. This is the only role that normally needs DataFactory and the traveller-app repository.

A normal curator generally needs only `YatraCanvas-CityPack_lab`. Do not clone `YatraCanvas-DataFactory` or `YatraCanvas` merely to fix a committed City Pack.

## Before starting work

Install Git, Flutter, the Windows desktop prerequisites shown by `flutter doctor`, and Python 3.12 or newer. Then clone and set up the project as described in the [README](README.md).

Start from the latest `main`:

```powershell
git checkout main
git pull origin main
git checkout -b curate/<city>-<name-or-task>
```

Examples:

```text
curate/jaipur-rohan
curate/jaipur-images
curate/udaipur-hours
fix/jaipur-duplicate-places
```

One branch per city or logical work item keeps the Pull Request understandable and reduces merge conflicts. The exact branch name is flexible; make it short and descriptive.

## What contributors edit

Make normal data changes through the Windows City Lab app. It stores small, reviewable records in:

```text
assets/city_packs/<city>/curation/
├── overrides/    field corrections
├── additions/    manually added places
├── exclusions/   reversible exclusions
├── reviews/      Manual QA decisions
├── issues/       unresolved or tracked defects
└── media/        curated-image metadata and attribution
```

Image import also creates or replaces:

```text
assets/city_packs/<city>/images/<place_id>/primary.webp
assets/city_packs/<city>/images/<place_id>/thumbnail.webp
```

If that image directory was not already registered, the importer adds it to `pubspec.yaml`. Review that shared-file change carefully.

### Do not manually edit `yatracanvas.db`

`assets/city_packs/<city>/yatracanvas.db` is the DataFactory-generated baseline. Human corrections belong in the curation layer because those files can be reviewed, merged, and reapplied. A direct database edit is difficult to audit and can disappear on regeneration.

## Image evidence

Only use an image whose source and licence you can verify. The desktop importer asks for the source, source page, licence, licence URL (from the chosen licence), and records the contributor. Preserve author/creator information wherever the source provides it; never invent attribution.

The current importer has a certification mismatch: it writes an empty `author` field, permits an empty source page, and assigns no licence URL to the **Contributor owned** option. Certified export requires non-empty `author`, `sourcePage`, and `licenseUrl`. Call any such gap out in the Pull Request and ask a release manager to resolve it from verifiable evidence before certification. Do not guess or silently fill it.

## Working safely with other contributors

- Divide work by city, category, place set, or task before starting.
- Avoid editing the same place or image as someone else unless you coordinate.
- Pull the latest `main` before creating a branch.
- Keep Pull Requests focused and reasonably small.
- Do not leave a branch untouched for weeks; update it from `origin/main` before asking for review.
- Resolve JSON conflicts record by record. Never discard another person's curation merely to make the conflict disappear.
- If image files or `pubspec.yaml` collide, inspect both contributors' changes rather than blindly choosing one side.
- Never run the baseline sync tool over important uncommitted work. It replaces synchronized baseline files and the entire city image directory.

## Validate before pushing

Replace `jaipur` with the City Pack ID you edited:

```powershell
.\citylab.ps1 summary -City jaipur
.\citylab.ps1 test
flutter analyze
```

The summary command creates `curation_summary.md`. Use it to prepare the PR, but do not automatically commit it.

If a test fails, do not delete or weaken the test. Determine whether the curation data or application behavior caused the failure, then fix the cause or report it in the PR.

## Inspect and stage changes

Never stage everything without first understanding the diff:

```powershell
git status
git diff
```

Stage only relevant paths. For a curation-only Jaipur change:

```powershell
git add assets/city_packs/jaipur/curation/
```

If image work occurred, stage only the applicable image directories and the asset-list change if it belongs to the import:

```powershell
git add assets/city_packs/jaipur/images/<place_id>/
git add pubspec.yaml
```

Then verify exactly what will be committed:

```powershell
git status
git diff --staged
```

Do not stage unrelated curation records, other contributors' files, `build/`, `.dart_tool/`, temporary exports, or unrelated `pubspec.yaml` edits.

## Commit messages

Use a simple description of the outcome:

```text
Curate Jaipur opening hours
Fix Jaipur place categories
Add Jaipur verified attraction images
Review Jaipur manual QA sample
Exclude duplicate Jaipur places
```

## Push and open a Pull Request

```powershell
git push -u origin curate/jaipur-yourname
```

Open a Pull Request from your branch into `main`. Contributors should normally **not** push directly to `main`.

The PR should state:

- the city;
- the type and number of changes;
- images, additions, exclusions, and reviews affected;
- Manual QA progress;
- reliable sources or evidence;
- validation commands run and their results;
- known unresolved issues.

Use the repository's Pull Request template and include the relevant curation summary. A contributor PR ends at review and merge; it does not production-publish the pack.

## Updating a branch later

First save or commit your own work. Then fetch and merge the latest `main` into the feature branch:

```powershell
git checkout curate/jaipur-yourname
git fetch origin
git merge origin/main
```

If there are conflicts, open each conflicted file, understand both sides, preserve valid work, run the validation commands again, and commit the resolution. Ask a maintainer when the correct data is unclear. Do not use `git reset --hard`, force-push, or discard one side as routine conflict handling.

## Do not do this

- Do not manually edit `yatracanvas.db`.
- Do not fabricate missing hours, coordinates, photos, categories, or evidence.
- Do not push directly to `main`.
- Do not production-publish as a normal contributor.
- Do not overwrite another contributor's curation to resolve a conflict.
- Do not run baseline synchronization over important uncommitted work.
- Do not commit unrelated generated or build files.
- Do not use an image whose source or licence cannot be verified.

## Need help?

Open a GitHub issue or ask the reviewer in your Pull Request. Include the city, place ID, what you tried, and any reliable source you found. It is better to leave an issue explicitly unresolved than to guess.

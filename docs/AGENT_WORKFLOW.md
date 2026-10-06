# Agent workflow

Last reviewed against repository: 2026-10-06.

## Installed skills and precedence

`[IMPLEMENTED]` The repository contains `scope`, `audit`, `architect`, `develop`,
`check`, `test`, `document`, `sync` and `debug` in `.agents/skills/`.
`skills-lock.json` records their imported source as `jsmastery-pro/skills`.
Local project guidance is added to the entrypoints; the lock file retains source metadata.

Read root [AGENTS.md](../AGENTS.md), [the contributor guide](CITY_LAB_CONTRIBUTOR_GUIDE.md),
[the curation architecture](CITY_LAB_CURATION_ARCHITECTURE.md) and
[quality architecture](CITY_LAB_QUALITY_ARCHITECTURE.md) for the area being changed.
For pack handoffs, read [offline architecture](OFFLINE_CITY_PACK_ARCHITECTURE.md) and
[the developer loop](CITY_DATA_DEV_LOOP.md). Repository instructions and the user's
requested scope take precedence over generic skill defaults.

`[IMPLEMENTED]` The separate `agent/skills/` directory contains compatibility copies.
On this inspected Windows checkout, `.claude/skills/<name>` is a junction to
`.agents/skills/<name>`; Git also tracks the files under the `.claude` paths.
Keep tracked compatibility copies consistent when changing an entrypoint.
Inspect links on the current host; other clones may contain ordinary directories.
Do not remove or recreate these directories as part of routine documentation work.

## Choosing a workflow

| Skill | Appropriate work |
| --- | --- |
| `scope` | Track a bounded Lab delivery slice in `docs/scope/` |
| `architect` | Resolve curation, schema, evidence or certification decisions in `docs/specs/` |
| `develop` | Implement an agreed Lab behavior in Flutter or Python tooling |
| `check` | Verify curator behavior or review implementation against its evidence |
| `test` | Add relevant coverage for changed widgets, quality rules or tooling |
| `debug` | Reproduce and fix a specific Lab defect |
| `document` | Draft PR, changelog, release or incident prose from actual changes |
| `audit`, `sync` | Add missing context or reconcile supported facts surgically |

These workflow states do not certify a city. Use `[IMPLEMENTED]`, `[PARTIAL]`,
`[PLANNED]`, `[DEPRECATED]` and `[UNKNOWN]` for architectural claims.
A green test suite or completed scope row cannot replace manual QA and Release Gate evidence.

## Data ownership and release operations

`[IMPLEMENTED]` The baseline `assets/city_packs/<city>/yatracanvas.db` is immutable.
Human changes live in curation sidecars and referenced media. Lab evaluation reads
bundled data; provider enrichment belongs to DataFactory or the traveller backend.
Preserve stable IDs, curator work, source evidence and image attribution.

A repair ZIP and a certified artifact are different outputs. The repair route uses
`tools/export_citylab_patch.py`, DataFactory `citylab-import --dry-run`, then an
authorized apply with a new output version. Certification uses READY evidence and
`tools/export_certified_pack.py`. Read [the release manager guide](RELEASE_MANAGER_GUIDE.md)
before publishing. Its current direct publication target is
`YatraCanvas/assets/city_packs/<city>/`; the local runtime consumes the separate
`assets/citypacks/` app projection through DataFactory `app-pack` and app sync.
Inspect these paths before claiming a certified publication updates the running app.

Test media stays explicitly classified and requires the documented opt-in.
Missing evidence stays unresolved. No skill may manufacture hours, photographs,
attribution or passing QA, rewrite an existing DataFactory release, or apply a
production database migration during repository work.
`[PARTIAL]` Physical Android acceptance remains separate from desktop verification.

## Verification and Git

For Flutter behavior, use targeted `flutter test` suites and `flutter analyze`.
For Python tooling, use `python -m pytest tools/tests -q` with an interpreter that
has the required dependencies. Read manifests and tool configuration before assuming
a Node or web framework workflow. Documentation changes need link and diff checks.

Contributor changes normally use a focused branch and PR into `main`, as described
in [CONTRIBUTING.md](../CONTRIBUTING.md). Reuse user authorization already given for
scoped commit, push or merge operations. Git publication does not authorize pack
publication, provider calls or changes in a sibling repository. Inspect and stage
explicit task files. Preserve curated instructions when using `audit` or `sync`.

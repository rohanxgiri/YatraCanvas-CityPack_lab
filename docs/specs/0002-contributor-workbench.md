# 0002 · Contributor workbench

**Status**: In Progress
**Date**: 2026-09-27

## Summary

Turn the contributor facing shell into a calm, responsive release workbench. The interface should answer three questions in order: what city is open, why it cannot ship, and what useful action should happen next.

## Context

The app already exposes all major quality capabilities, but its first screens give equal weight to diagnostics, pack internals, blended scores, and contributor tasks. Desktop users still receive a mobile bottom bar, narrow layouts can overflow, and the visual language does not distinguish a hard release blocker from a general quality indicator.

## Options considered

1. Restyle every screen in one pass. This promises consistency but combines unrelated workflows and makes behavioral regression likely.
2. Add a third party dashboard kit. This would create a second component language and does not solve the information hierarchy.
3. Rebuild the primary contributor journey on Material 3 with a local token layer, then extend it journey by journey. Chosen.

## Requirements

- **AC-1:** The interface uses one shared Material 3 color, type, spacing, radius, and component system with readable contrast and 44 px minimum interactive targets.
- **AC-2:** At 900 px and wider, the city workbench uses a labelled navigation rail; below 900 px it uses bottom navigation without clipped destinations.
- **AC-3:** Contributor and Admin modes remain available, but diagnostics are visually secondary to Home, Fix, Review, Places, and Release.
- **AC-4:** Pack selection explains the offline, immutable input model once and shows packs in a responsive grid with one clear Open action.
- **AC-5:** Home gives release status and critical blockers more authority than any blended score and exposes one primary next action.
- **AC-6:** Home presents a visible Fix → Review → Release runway plus concise task cards for photos, schedules, locations, and duplicates.
- **AC-7:** Loading, empty, invalid pack, and evaluation states use plain language with a recovery action where possible.
- **AC-8:** The updated journey remains keyboard operable and avoids narrow screen overflows at 360 px.

## Decision

Use the existing Flutter Material 3 stack and introduce a small local token layer rather than a third party widget system. The visual direction is an editorial field notebook: warm paper surfaces, deep teal structure, saffron for attention, restrained elevation, and large plain language status text.

The signature differentiator is the release runway, a numbered progress path that connects daily fixing work to manual review and certification. Motion is limited to state transitions and progress changes; there is no decorative animation.

## Feature design

### Composition

1. Pack selection: purpose statement, operating mode note, responsive city cards.
2. Workbench shell: city identity, mode controls, responsive navigation.
3. Home: release status hero, primary next action, release runway, task queue, score evidence.
4. Fix and review: inherit the same surfaces and button hierarchy; media curation is the first fully rebuilt task.

### Component inventory

- `LabTheme` tokens and theme builder
- responsive shell using `NavigationRail` and `NavigationBar`
- status hero and release runway
- task card with count, explanation, and action
- pack card with integrity, place, and media summary

### Content rules

- Say “blocked” and name the blocker. Do not soften it with a blended health score.
- Keep engine names and formulas in Advanced mode.
- Use sentence case, familiar nouns, and action labels that describe the result.
- Pair every status color with text and an icon.

### Value sourcing

| Displayed value | Source |
|---|---|
| Pack identity, version, place and image counts | `CityPack` and `CityPackRegistry` |
| Release state and blocker count | `AppState.releaseGateResult` |
| Photo, hours, location, and duplicate work counts | `AppState.qualityStats` plus open curation issues |
| Manual review progress | `AppState.manualQaSummary` |
| Data quality and travel readiness evidence | the two existing score services |
| Current workbench destination | local shell navigation state |
| Contributor and Admin mode | `AppState.contributorName` and `AppState.isAdminMode` |

### Critical test scenarios

- **AC-1:** theme contrast, button sizes, and visible text hierarchy on the primary screens.
- **AC-2, AC-8:** 360 px uses bottom navigation without overflow; 1200 px uses a labelled rail.
- **AC-3:** toggling Admin mode adds or removes Advanced without losing the current contributor destination.
- **AC-4:** loading, empty, invalid, and populated pack states each give a clear next action.
- **AC-5:** a blocked pack shows BLOCKED and the actual blockers above any score.
- **AC-6:** runway and task counts reflect QA and quality state changes.

## Migration plan

**Strategy:** Keep all routes and screen contracts stable while replacing only the app root theme, pack selector composition, workbench shell, and Home composition.

**Phases:** Introduce tokens first, migrate the shell, migrate selection and Home, then repair responsive and accessibility issues discovered in the live app.

**Rollback:** Each surface is isolated by file. Reverting it restores the previous presentation without a data migration.

**Risks:** A responsive rail can desynchronize selected indexes when Admin mode changes, dense metrics can still overflow on narrow screens, and a softer palette can reduce status contrast. Indexes are clamped, layouts use width based composition, and blocker colors retain explicit labels and icons.

## Build plan

1. Add the shared theme and tokens, then apply them at the app root. Covers AC-1.
2. Rebuild the city shell with responsive rail and bottom navigation while retaining Admin mode and current pages. Covers AC-2, AC-3, and AC-8.
3. Recompose pack selection and Home around the purpose statement, release blockers, next action, and release runway. Covers AC-4 through AC-7.
4. Run desktop and narrow browser checks, repair overflows and semantics, and add stable widget coverage. Covers AC-1, AC-2, AC-7, and AC-8.

## Consequences

The core contributor path becomes easier without removing specialist capability. Some legacy screens will remain visually older until their journey is rebuilt. The token layer prevents the new surfaces from becoming another set of one off colors and spacing values.

## Follow-up

- Apply the same components to Places and Release detail screens.
- Remove or archive orphaned legacy QA screens after route usage is confirmed.

## Rationale

The current app already has the right five operational pillars, but equal visual weight, technical labels, and mobile only navigation make it harder to understand on desktop. A responsive workbench preserves the architecture and changes the information hierarchy. The runner up was a full visual rewrite of every screen, rejected because it would mix several contributor journeys and make verification less reliable.

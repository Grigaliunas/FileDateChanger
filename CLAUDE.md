# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A native macOS SwiftUI utility for batch-changing file/folder creation and
modification dates — a reimplementation of the discontinued "File Date Changer 5"
(see `info.txt` for the original feature list this app is modeled on).

## Build & run

```bash
# Build (Debug)
xcodebuild -project FileDateChanger.xcodeproj -scheme FileDateChanger -configuration Debug build

# Run unit tests
xcodebuild -project FileDateChanger.xcodeproj -scheme FileDateChanger -destination 'platform=macOS' test

# Open in Xcode to run with the GUI (Cmd-R) or test (Cmd-U)
open FileDateChanger.xcodeproj
```

The `FileDateChangerTests` target uses **Swift Testing** (`import Testing`,
`@Test`, `#expect`):
- `FileDateServiceTests` — pure logic (planning, correction, expansion).
- `FileDateApplyTests` — integration tests that `apply` changes to real temp
  files and read the dates back; compare at whole-second granularity because
  on-disk dates carry sub-second noise.

It is a hosted test bundle (`TEST_HOST` = the app) so `@testable import
FileDateChanger` works; the app must keep `ENABLE_TESTABILITY = YES` in Debug.
The shared scheme wires the test target into the Test action. New `.swift` files
dropped into `FileDateChangerTests/` are picked up automatically (synchronized
group) — no `project.pbxproj` edits needed.

## Workflow & releasing

`main` is protected: changes land via PR, and the required `Build & Test (macOS)`
check (`.github/workflows/ci.yml`) must pass before merge (enforced for admins
too). Typical loop: branch → PR → `gh pr merge --squash --auto` → it self-merges
when CI is green and the branch auto-deletes.

To release: add the version's notes under a `## [x.y.z]` heading in
`CHANGELOG.md`, then push a matching `vx.y.z` tag. `.github/workflows/release.yml`
fires on `v*` tags, extracts that changelog section, and creates the GitHub
release (idempotent; falls back to auto-generated notes if the section is absent).

## Project layout & conventions

- The Xcode project uses a **file-system-synchronized root group** (`objectVersion = 77`).
  Any `.swift` file added under `FileDateChanger/` is compiled automatically — you
  do **not** need to edit `project.pbxproj` when adding or removing source files.
- `MACOSX_DEPLOYMENT_TARGET = 14.0`, `SWIFT_VERSION = 5.0`.
- **App Sandbox is intentionally disabled** so the app can read/write dates on
  arbitrary user-selected files. If sandbox is ever enabled, file access must come
  through the open panel or drag & drop (powerbox-granted) and `.creationDate`
  writes may be restricted.

## App icon

The icon set in `FileDateChanger/Assets.xcassets/AppIcon.appiconset` is generated,
not hand-drawn. To regenerate (e.g. after a design tweak), edit the drawing code in
`Tools/generate-appicon.swift` and run:

```bash
swift Tools/generate-appicon.swift
```

It renders all 10 macOS sizes with AppKit and rewrites the PNGs + `Contents.json`.
The PNGs are committed; the script is the source of truth.

## Architecture

Single-window app; data flows one way through a single `@MainActor` store.

- `Models/AppModel.swift` — the `ObservableObject` store (file list, selection,
  `ActionConfig`, processing state). Injected via `.environmentObject`.
- `Models/ActionConfig.swift` — the user's choices: which `DateActionKind`, which
  dates (`DateFieldSelection`), and per-action parameters.
- `Services/FileDateService.swift` — **all** date logic lives here as stateless
  functions. `plannedChange(for:config:)` is a **pure function**: the preview in
  the table and the actual write share this exact computation, so what you see is
  what gets written.
- `Models/PlannedChange.swift` — computed `(item → newCreation/newModification)`;
  drives both the preview UI and `FileDateService.apply`.

Key invariant: the preview and the write are never computed by different code
paths. `AppModel.plannedChanges` maps every item through `FileDateService`, the
table renders that, and `performChanges()` writes exactly those same
`PlannedChange` values (filtered to `hasChanges`).

### macOS file-date rules (`FileDateService.correct`)

macOS rejects "impossible" dates. When *Auto-correct inconsistent dates* is on:
future dates are clamped to now, and modification is forced to be ≥ creation.
Note the Finder also silently rewrites pre-1972 dates to 1972-01-01 — this is OS
behavior, not the app.

### Removing dates (`FileDateService.noDate`)

The "Remove dates" action writes the **HFS+ epoch zero — 1904-01-01 00:00:00 GMT**
(`Date(timeIntervalSince1970: -2_082_844_800)`). Finder renders that sentinel as
"-----" (verified: `mdls` reports `1904-01-01 00:00:00 +0000`; Finder's AppleScript
returns a garbage date for it). This writes through the normal
`FileManager.setAttributes` path — no raw `setattrlist` needed. Two consequences
baked into the code:
- `plannedChange` **skips inconsistency correction** for `.removeDates`, otherwise
  a removed modification date would be clamped back up to creation.
- The date display (`Optional<Date>.displayString`) shows "-----" for both `nil`
  and the `noDate` sentinel (`FileDateService.isNoDate`).
- Beware GetFileInfo shows "01/01/1904 01:24:00" for any low/zero timestamp — that
  is a GetFileInfo quirk; trust `mdls`/`stat` for the real stored value.

## Gotchas

- Date comparisons in `PlannedChange` are done at **whole-second** granularity —
  file dates carry sub-second noise that would otherwise show spurious "changed".
- `reloadDates()` rebuilds `items` as **new `FileItem` instances** (fresh ids)
  rather than mutating in place. SwiftUI's `Table` caches row cells by row
  identity; an in-place date change on the same `id` leaves stale values visible
  even though derived state (e.g. the toolbar's change counter) updates. Keep the
  rebuild — do not "optimize" it back to in-place mutation.
- `includeSubfolderContents` expands folders **at add time only**; toggling it
  afterward does not retroactively expand items already in the list.
- `info.txt` and `macupdater_latest.dmg` are reference/download artifacts, not part
  of the app. The `.dmg` is git-ignored.

# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.2] - 2026-06-21

### Added

- README: a screenshot of the **Remove dates** action.

## [1.0.1] - 2026-06-21

### Changed

- Maintenance release: added GitHub Actions release automation and wired up the
  changelog comparison links. No changes to the app itself.

## [1.0.0] - 2026-06-21

### Added

- Initial release — a native SwiftUI (macOS 14+) tool for batch-changing file and
  folder dates, modeled on the discontinued *File Date Changer 5*.
- Build a list by drag & drop or **File ▸ Add Files… (⌘O)**.
- Live preview table showing each item's current dates and the new value.
- Actions:
  - Set to a specific date.
  - Add / remove time (days, hours, minutes, seconds).
  - Copy creation → modification and modification → creation.
  - Lift dates from another file.
  - Remove dates (the Finder shows the item as `-----`).
- Apply to creation only, modification only, or both.
- Auto-correct inconsistent dates (clamp future dates to now; keep modification ≥ creation).
- Batch apply with a confirmation step and a success/error summary.
- Generated app icon (`Tools/generate-appicon.swift`).

[Unreleased]: https://github.com/Grigaliunas/FileDateChanger/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/Grigaliunas/FileDateChanger/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/Grigaliunas/FileDateChanger/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Grigaliunas/FileDateChanger/releases/tag/v1.0.0

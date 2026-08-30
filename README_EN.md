# Romeo Daily Ledger

[简体中文](README.md) | English

## Overview

Romeo Daily Ledger is a native personal ledger app for macOS 14 and later. The project is in early development: the current interface is an application shell that displays **“Romeo Daily Ledger”**, while the initial domain model and test foundation are in place.

## Project Status

This repository is not yet a complete bookkeeping application. A SwiftData repository implementation now exists, but it is not wired into the application lifecycle. Transaction recording, category management, and reports remain planned work rather than finished features.

## Implemented Foundation

- Expense and income entry types through `EntryKind`
- `LedgerEntry` with a `Decimal` amount, category identifier, note, occurrence timestamp, and created/updated timestamps
- `Category` with an expense or income kind, a system-category identifier or a custom name, icon, color, sort order, and hidden state
- `LedgerDraft` amount parsing and validation that rejects zero, negative, and unparseable values
- An in-memory SwiftData `ModelContainer` factory
- `LedgerRepository` and `SwiftDataLedgerRepository` operations for insertion, updates, batch deletion, half-open date-range entry queries, kind-filtered category queries, and category lookup
- Idempotent default expense and income category seeding, with a matching `other` category fallback for uncategorized entries
- Unit tests for app naming, amount validation, decimal precision, default seeding and idempotence, category fallback, half-open date queries, updates, and batch deletion
- A UI launch smoke test

## Tech Stack

- Swift 6
- SwiftUI
- SwiftData
- XCTest
- Swift Testing
- XcodeGen (optional project generation)

## Requirements

- macOS 14.0 or later
- A recent Xcode version with Swift 6 support
- XcodeGen, only if you want to regenerate the Xcode project from `project.yml`

## Getting Started

1. Clone the repository and enter its directory:

   ```bash
   git clone https://github.com/DUGUSHUANGTAN/Romeo-Daily-Ledger.git
   cd Romeo-Daily-Ledger
   ```

2. Optional: regenerate the Xcode project from `project.yml`:

   ```bash
   xcodegen generate
   ```

   A generated `.xcodeproj` is already checked in, so this step is not required for normal use.

3. Open the project:

   ```bash
   open RomeoDailyLedger.xcodeproj
   ```

4. Build and run the `RomeoDailyLedger` scheme in Xcode.

5. Build from the command line:

   ```bash
   xcodebuild build \
     -project RomeoDailyLedger.xcodeproj \
     -scheme RomeoDailyLedger \
     -destination 'platform=macOS'
   ```

6. Run the test suite from the command line:

   ```bash
   xcodebuild test \
     -project RomeoDailyLedger.xcodeproj \
     -scheme RomeoDailyLedger \
     -destination 'platform=macOS'
   ```

## V1.0.0 Release Packaging

The Release configuration uses `MARKETING_VERSION = 1.0.0` and `CURRENT_PROJECT_VERSION = 1`. The app name remains “Romeo Daily Ledger” (English) and “罗密欧每日记账” (Simplified Chinese); the version appears only in app metadata and package filenames.

```bash
./scripts/build_release.sh  # Build the Release .app
./scripts/create_dmg.sh     # Create the DMG and SHA-256 checksum
```

Artifacts are written to `build/release/` by default: `Romeo Daily Ledger.app`, `Romeo-Daily-Ledger-1.0.0.dmg`, and its `.sha256` file. The DMG contains the app and an `/Applications` shortcut. Set `BUILD_DIR=/path/to/output` to change the destination, or use `SKIP_BUILD=1 ./scripts/create_dmg.sh` when the app has already been built.

The scripts create an unsigned archive for local validation and GitHub Release preparation. Complete Developer ID signing and notarization in a trusted release environment before public distribution. These scripts do not create a GitHub Release or upload files.

## Project Structure

```text
.
├── Config/                         # Debug and Release build configuration
├── RomeoDailyLedger/
│   ├── App/                        # App entry point and current root view
│   ├── Domain/                     # Ledger, category, and draft models
│   ├── Infrastructure/Persistence/ # SwiftData container, default categories, and repository
│   └── Resources/                  # App resources, including Info.plist
├── RomeoDailyLedgerTests/          # Unit tests and app name tests
├── RomeoDailyLedgerUITests/        # UI launch smoke tests
├── RomeoDailyLedger.xcodeproj/     # Checked-in Xcode project
└── project.yml                     # XcodeGen project specification
```

## Roadmap

- [ ] Build the income and expense recording interface and complete its interactions
- [ ] Wire the existing repository and persistent SwiftData container into the application lifecycle
- [ ] Add entry lists, details, editing, and deletion
- [ ] Add category creation, editing, sorting, hiding, and system category presentation
- [ ] Add income and expense summaries, trends, and category breakdowns
- [ ] Add search, filtering, and date-range queries
- [ ] Expand unit, integration, and UI test coverage

The roadmap describes intended direction and is not a delivery commitment.

## Contributing

Issues and suggestions are welcome, as are pull requests. Before submitting code, keep the scope of the change clear and run the existing tests. New features should include corresponding tests and documentation where appropriate.

## License

This project is available under the [MIT License](LICENSE).

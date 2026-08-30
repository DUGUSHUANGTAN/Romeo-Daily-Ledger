# Romeo Daily Ledger

[简体中文](README.md) | English

## Overview

Romeo Daily Ledger is a native, local-first personal ledger app for macOS 14 and later. It requires no account and keeps ledger data on the Mac.

## Project Status

V1.0.0 includes daily bookkeeping, calendar review, multi-selection totals, categories, basic insights, bilingual themes, AI-assisted entry and analysis, JSON/CSV transfer, and manual GitHub update checks.

## Features

- Create, edit, and delete income and expense entries; choose the ledger currency in General settings.
- Calendar review, multi-selection totals, monthly income/expense/balance trends, and category breakdowns.
- Light/dark themes, typography and motion settings, with complete English and Simplified Chinese UI.
- OpenAI Chat Completions and Responses-compatible AI services without vendor SDKs. API keys stay in macOS Keychain.
- AI drafts remain editable and are saved only after confirmation. AI analysis requires explicit permission and a visible date scope.
- JSON/CSV import and export with preview, duplicate handling, currency validation, and atomic batch insertion.
- Manual GitHub Release update checks with no automatic installation.

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

Unsigned builds are supported for local use. For public distribution, run `SIGNING_IDENTITY="Developer ID Application: …" ./scripts/build_release.sh`, then notarize with `NOTARY_PROFILE=profile SKIP_BUILD=1 ./scripts/create_dmg.sh`. From the artifact directory, verify a download with `shasum -a 256 -c Romeo-Daily-Ledger-1.0.0.dmg.sha256`.

Open the DMG and drag Romeo Daily Ledger to Applications. An unsigned local build may require choosing **Open** from Finder’s context menu on first launch.

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

## Future Direction

- Optional iCloud sync and automated backups
- Additional insight dimensions and customizable reports
- A signed and notarized public release pipeline

## Contributing

Issues and suggestions are welcome, as are pull requests. Before submitting code, keep the scope of the change clear and run the existing tests. New features should include corresponding tests and documentation where appropriate.

## License

This project is available under the [MIT License](LICENSE).

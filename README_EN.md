# Romeo Daily Ledger

[简体中文](README.md) | English

> A native, local-first personal ledger app for macOS. No account required; your ledger stays on your Mac.

## Overview

- macOS 14 or later
- Built with Swift 6, SwiftUI, and SwiftData
- Current release: v1.1.0 (Apple Silicon / arm64)
- MIT License

## Features

- Create, edit, and delete income and expense entries
- Calendar review, multi-selection totals, and monthly insights
- Custom category management
- Simplified Chinese, Traditional Chinese, and English interfaces
- Light and dark themes that follow the system
- AI entry and analysis through OpenAI Chat Completions / Responses-compatible services
- JSON / CSV import and export with preview, duplicate handling, currency validation, and atomic batch insertion
- Manual GitHub Release update checks with no automatic installation

## Download and install

1. Open [GitHub Releases](https://github.com/DUGUSHUANGTAN/Romeo-Daily-Ledger/releases) and download the latest DMG.
2. Open the DMG and drag Romeo Daily Ledger to the Applications folder.
3. If macOS cannot verify the developer on first launch, right-click the app in Finder and choose **Open**.

The current release provides an Apple Silicon (arm64) build.

## Data and privacy

- No account is required. Ledger data is stored locally on the current Mac user account and is not uploaded or synchronized automatically.
- The default data directory is:

  ```text
  ~/Library/Application Support/com.romeoke.RomeoDailyLedger/
  ```

- The ledger is stored in a local SwiftData database. App settings and API keys are stored in a local `settings.json` file readable and writable only by the current macOS user.
- API keys are excluded from JSON / CSV ledger exports.
- When AI features are enabled and used, the relevant request is sent to the API endpoint you configure. Review that provider's privacy policy before using the feature.
- You can choose a different local parent folder under **Settings → General → Data & Storage**. The app creates a `Romeo Daily Ledger Data` subfolder and validates and migrates the data before the next launch.

## Development

### Requirements

- macOS 14+
- Xcode with Swift 6 support
- Optional: XcodeGen, to regenerate the Xcode project

`RomeoDailyLedger.xcodeproj` is checked in. To regenerate it from `project.yml`:

```bash
xcodegen generate
```

### Test, build, and package

```bash
# Run unit and UI tests
xcodebuild test -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS'

# Build a Release version
./scripts/build_release.sh

# Create a DMG
./scripts/create_dmg.sh
```

Signing and notarization are optional. Provide `SIGNING_IDENTITY` and `NOTARY_PROFILE` when needed. Without a Developer ID, the release script applies a complete Ad Hoc signature; a downloaded build may still require the Finder **Open** action on first launch.

## License

This project is released under the [MIT License](LICENSE).

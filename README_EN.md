# Romeo Daily Ledger

[简体中文](README.md) | English

Romeo Daily Ledger is a native, local-first personal ledger app for macOS. It requires no account and keeps ledger data on the Mac.

## Features

- Income and expense entry, editing, deletion, calendar review, multi-selection totals, and monthly insights.
- Category management, English and Simplified Chinese UI, and light/dark themes that follow the system.
- AI entry and analysis through OpenAI Chat Completions / Responses-compatible services. API keys are stored in macOS Keychain and are excluded from ledger exports.
- JSON / CSV import and export with preview, duplicate handling, currency validation, and atomic batch insertion.
- Manual GitHub Release update checks with no automatic installation.

## Install

Download the DMG from [GitHub Releases](https://github.com/DUGUSHUANGTAN/Romeo-Daily-Ledger/releases), open it, and drag Romeo Daily Ledger to Applications.

V1.1.0 provides an Apple Silicon build. Without a Developer ID, the first launch may require right-clicking the app in Finder and choosing **Open**.

## Data storage

The default data directory is `~/Library/Application Support/com.romeoke.RomeoDailyLedger/`, containing the SwiftData store and `settings.json`. Choose a different local parent folder under **Settings → General → Data & Storage**; the app creates a `Romeo Daily Ledger Data` subfolder and validates and migrates the data before the next launch.

## Development

- Swift 6, SwiftUI, SwiftData
- macOS 14+
- `RomeoDailyLedger.xcodeproj` is checked in; run `xcodegen generate` to regenerate it when needed.

```bash
xcodebuild test -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS'
./scripts/build_release.sh
./scripts/create_dmg.sh
```

Signing and notarization are optional through `SIGNING_IDENTITY` and `NOTARY_PROFILE`. Without a Developer ID, the release script applies a complete ad-hoc signature; a downloaded build may require one first launch via Finder's “Open” action.

## License

[MIT License](LICENSE)

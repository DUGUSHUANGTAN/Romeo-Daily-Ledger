# Romeo Daily Ledger

[简体中文](README.md) | English

Romeo Daily Ledger is a native, local-first personal ledger app for macOS. It requires no account and keeps ledger data on the Mac.

## Features

- Income and expense entry, editing, deletion, calendar review, multi-selection totals, and monthly insights.
- Category management, English and Simplified Chinese UI, light/dark themes, typography, and motion settings.
- AI entry and analysis through OpenAI Chat Completions / Responses-compatible services. API keys stay in macOS Keychain, drafts are saved only after confirmation, and analysis requires a visible authorized date range.
- JSON / CSV import and export with preview, duplicate handling, currency validation, and atomic batch insertion.
- Manual GitHub Release update checks with no automatic installation.

## Install

Download the DMG from [GitHub Releases](https://github.com/DUGUSHUANGTAN/Romeo-Daily-Ledger/releases), open it, and drag Romeo Daily Ledger to Applications.

V1.0.0 currently provides an unsigned build for personal use. On first launch, you may need to right-click the app in Finder and choose **Open**. Verify the download from its directory with:

```bash
shasum -a 256 -c Romeo-Daily-Ledger-1.0.0.dmg.sha256
```

## Development

- Swift 6, SwiftUI, SwiftData
- macOS 14+
- `RomeoDailyLedger.xcodeproj` is checked in; run `xcodegen generate` to regenerate it when needed.

```bash
xcodebuild test -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS'
./scripts/build_release.sh
./scripts/create_dmg.sh
```

Signing and notarization are optional through `SIGNING_IDENTITY` and `NOTARY_PROFILE`.

## License

[MIT License](LICENSE)

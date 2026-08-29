# 手动更新、开源与发布实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**Goal:** Add a strictly user-initiated Sparkle update flow backed by GitHub, finish the original visual identity and open-source repository materials, and establish repeatable CI/release verification without publishing anything automatically.

**Architecture:** `UpdateService` owns a lazily started Sparkle adapter and exposes one explicit `checkForUpdates()` action. App launch and scene changes never invoke it. GitHub Pages serves the signed appcast while GitHub Releases stores signed/notarized archives. Repository policies, privacy documentation, third-party notices, CI, and release scripts live beside the app and are independently verifiable.

**Tech Stack:** Swift 5.10, SwiftUI, Sparkle 2, XcodeGen, Swift Testing, XCTest UI tests, GitHub Actions, GitHub Pages, GitHub Releases, Developer ID signing/notarization, EdDSA appcast signatures, Lucide SVG icons.

**Approved design source:** `docs/superpowers/specs/2026-08-29-romeo-daily-ledger-design.md`

**Global constraints:**

- 启动及后台不访问更新源；打开设置也不检查。只有用户点击“检查更新”后才允许读取 GitHub Pages appcast。
- Do not call any update API at launch, activation, scene change, or on a timer.
- Do not show automatic-check, automatic-download, or automatic-install controls.
- Do not publish, push, create a GitHub Release, alter repository settings, or upload secrets without fresh explicit user authorization.
- Never store the Sparkle EdDSA private key in this repository; keep it in the release machine Keychain or GitHub Actions secrets.
- Before creating visual assets, read and apply `/Users/romeoke/.codex/skills/design-taste-frontend/SKILL.md`. Use original vector artwork and Lucide's open-source SVG icon set only.
- Swift Testing files begin with `import Testing` and `@testable import RomeoDailyLedger`; UI tests begin with `import XCTest`.

---

## Task 1: Add a lazy, manual-only Sparkle update boundary

**Files:**

- Modify: `project.yml`
- Modify: `RomeoDailyLedger/Resources/Info.plist`
- Create: `RomeoDailyLedger/Infrastructure/Updates/UpdaterClient.swift`
- Create: `RomeoDailyLedger/Infrastructure/Updates/SparkleUpdaterClient.swift`
- Create: `RomeoDailyLedger/Infrastructure/Updates/UpdateService.swift`
- Create: `RomeoDailyLedgerTests/Updates/UpdateServiceTests.swift`

- [ ] **步骤 1：编写失败的手动触发测试**

```swift
import Testing
@testable import RomeoDailyLedger

@MainActor
struct UpdateServiceTests {
    @Test func constructionAndLaunchDoNotStartOrCheck() {
        let client = RecordingUpdaterClient()
        _ = UpdateService(client: client)

        #expect(client.startCount == 0)
        #expect(client.checkCount == 0)
    }

    @Test func onlyExplicitUserActionStartsThenChecks() {
        let client = RecordingUpdaterClient()
        let service = UpdateService(client: client)

        service.checkForUpdates()
        service.checkForUpdates()

        #expect(client.startCount == 1)
        #expect(client.checkCount == 2)
    }
}

@MainActor
private final class RecordingUpdaterClient: UpdaterClient {
    private(set) var startCount = 0
    private(set) var checkCount = 0
    func startIfNeeded() { startCount += 1 }
    func checkForUpdates() { checkCount += 1 }
}
```

- [ ] **步骤 2：运行定向测试并确认失败**

Run:

```bash
xcodegen generate
xcodebuild test -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' -only-testing:RomeoDailyLedgerTests/UpdateServiceTests
```

Expected: FAIL because the update types do not exist.

- [ ] **步骤 3：加入 Sparkle 和最小生产边界**

Add to `project.yml`:

```yaml
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: 2.7.0

targets:
  RomeoDailyLedger:
    dependencies:
      - package: Sparkle
```

Implement:

```swift
@MainActor
protocol UpdaterClient: AnyObject {
    func startIfNeeded()
    func checkForUpdates()
}

@MainActor
final class UpdateService: ObservableObject {
    private let client: UpdaterClient
    init(client: UpdaterClient) { self.client = client }

    func checkForUpdates() {
        client.startIfNeeded()
        client.checkForUpdates()
    }
}
```

`SparkleUpdaterClient` owns `SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)`, sets automatic checking and downloading to `false`, starts it once on the first explicit action, and then calls Sparkle's foreground `checkForUpdates(nil)` API.

Set these generated `Info.plist` values:

```xml
<key>SUEnableAutomaticChecks</key>
<false/>
<key>SUAutomaticallyUpdate</key>
<false/>
<key>SUAllowsAutomaticUpdates</key>
<false/>
<key>SUEnableSystemProfiling</key>
<false/>
<key>SUFeedURL</key>
<string>https://dugushuangtan.github.io/Romeo-Daily-Ledger/appcast.xml</string>
```

Do not add a launch hook, timer, `scenePhase` hook, or `SPUUpdater` call elsewhere.

- [ ] **步骤 4：运行定向测试并确认成功**

Run the Step 2 command again.

Expected: PASS, with start count `1` and checks equal to explicit actions only.

- [ ] **步骤 5：提交**

```bash
git add project.yml RomeoDailyLedger/Resources/Info.plist RomeoDailyLedger/Infrastructure/Updates RomeoDailyLedgerTests/Updates/UpdateServiceTests.swift
git commit -m "feat: add manual-only update service"
```

---

## Task 2: Build the Software Update settings screen

**Files:**

- Create: `RomeoDailyLedger/Features/Settings/Updates/SoftwareUpdateSettingsView.swift`
- Modify: `RomeoDailyLedger/Features/Settings/General/GeneralSettingsView.swift`
- Modify: `RomeoDailyLedger/Resources/Localization/zh-Hans.lproj/Localizable.strings`
- Modify: `RomeoDailyLedger/Resources/Localization/en.lproj/Localizable.strings`
- Create: `RomeoDailyLedgerUITests/SoftwareUpdateSettingsUITests.swift`

- [ ] **步骤 1：编写失败的 UI 测试**

```swift
import XCTest

final class SoftwareUpdateSettingsUITests: XCTestCase {
    func testUpdatePanelHasOneManualActionAndNoAutomaticControls() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-language", "zh-Hans"]
        app.launch()

        app.buttons["settings-button"].click()
        app.buttons["settings-general"].click()
        app.buttons["software-update-row"].click()

        XCTAssertTrue(app.staticTexts["current-version-label"].exists)
        XCTAssertTrue(app.buttons["check-for-updates-button"].exists)
        XCTAssertFalse(app.switches["automatic-update-toggle"].exists)
        XCTAssertFalse(app.switches["automatic-check-toggle"].exists)
    }
}
```

- [ ] **步骤 2：运行并确认失败**

```bash
xcodebuild test -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' -only-testing:RomeoDailyLedgerUITests/SoftwareUpdateSettingsUITests
```

Expected: FAIL because the panel and accessibility identifiers do not exist.

- [ ] **步骤 3：实现已批准的设置面板**

The panel contains only:

- localized title “软件更新” / “Software Update”;
- current app name and `CFBundleShortVersionString`;
- current build number;
- a short privacy note that a request is made only after clicking;
- one prominent “检查更新” / “Check for Updates” button wired to `UpdateService.checkForUpdates()`.

Do not place keyboard shortcut badges in the sidebar. Do not expose automatic-update switches. Give the row, labels, and button the identifiers used by the test.

- [ ] **步骤 4：运行 UI 测试和双语测试**

Run the Step 2 command, then:

```bash
xcodebuild test -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' -only-testing:RomeoDailyLedgerUITests/LocalizationUITests
```

Expected: PASS; the Chinese launch contains no English setting labels and the English launch contains no Chinese setting labels.

- [ ] **步骤 5：提交**

```bash
git add RomeoDailyLedger/Features/Settings/Updates RomeoDailyLedger/Features/Settings/General/GeneralSettingsView.swift RomeoDailyLedger/Resources/Localization RomeoDailyLedgerUITests/SoftwareUpdateSettingsUITests.swift
git commit -m "feat: add manual software update settings"
```

---

## Task 3: Lock the no-background-update guarantee with source-level tests

**Files:**

- Create: `RomeoDailyLedgerTests/Updates/UpdatePolicyTests.swift`
- Modify: `RomeoDailyLedger/App/RomeoDailyLedgerApp.swift`
- Modify: `RomeoDailyLedger/Infrastructure/Updates/SparkleUpdaterClient.swift`

- [ ] **步骤 1：编写失败的更新策略测试**

```swift
import Foundation
import Testing

struct UpdatePolicyTests {
    @Test func plistDisablesEveryAutomaticUpdateCapability() throws {
        let plist = try TestBundleInfo.loadGeneratedInfoPlist()
        #expect(plist["SUEnableAutomaticChecks"] as? Bool == false)
        #expect(plist["SUAutomaticallyUpdate"] as? Bool == false)
        #expect(plist["SUAllowsAutomaticUpdates"] as? Bool == false)
        #expect(plist["SUEnableSystemProfiling"] as? Bool == false)
    }

    @Test func forbiddenUpdateTriggersAreAbsentFromApplicationSources() throws {
        let source = try RepositorySource.readApplicationSwiftFiles(
            excluding: ["SoftwareUpdateSettingsView.swift", "UpdateService.swift", "SparkleUpdaterClient.swift"]
        )
        #expect(!source.contains("checkForUpdates("))
        #expect(!source.contains("automaticallyChecksForUpdates = true"))
        #expect(!source.contains("scheduledCheckInterval"))
    }
}
```

Add deterministic test helpers under `RomeoDailyLedgerTests/Support/RepositorySource.swift` and `RomeoDailyLedgerTests/Support/TestBundleInfo.swift`; resolve paths from `#filePath`, never from the developer's absolute path.

- [ ] **步骤 2：运行并确认失败**

```bash
xcodebuild test -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' -only-testing:RomeoDailyLedgerTests/UpdatePolicyTests
```

Expected: FAIL until the generated plist and source boundary match the policy.

- [ ] **步骤 3：移除隐式触发并只向设置注入服务**

Create the Sparkle-backed service in the app composition root without starting it. Pass it through the settings environment. Verify that app launch, window creation, activation, and `scenePhase` changes perform no update action.

- [ ] **步骤 4：运行测试**

Run the Step 2 command.

Expected: PASS with all four automatic flags false and no forbidden trigger outside the three allowlisted update files.

- [ ] **步骤 5：提交**

```bash
git add RomeoDailyLedger/App/RomeoDailyLedgerApp.swift RomeoDailyLedger/Infrastructure/Updates/SparkleUpdaterClient.swift RomeoDailyLedgerTests/Updates/UpdatePolicyTests.swift RomeoDailyLedgerTests/Support
git commit -m "test: enforce user-initiated update policy"
```

---

## Task 4: Create the original brand assets and audited Lucide icon pipeline

**Files:**

- Create: `Brand/RomeoDailyLedgerMark.svg`
- Create: `docs/assets/cover-light.svg`
- Create: `docs/assets/cover-dark.svg`
- Create: `Scripts/generate_app_icon.swift`
- Create: `Scripts/sync_lucide_icons.sh`
- Create: `RomeoDailyLedger/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `RomeoDailyLedger/Resources/Assets.xcassets/Icons/`
- Create: `RomeoDailyLedgerTests/Brand/IconManifestTests.swift`

- [ ] **步骤 1：应用设计技能并记录视觉约束**

Read `/Users/romeoke/.codex/skills/design-taste-frontend/SKILL.md` completely before editing assets. Translate the approved light/dark directions into:

- warm-paper, forest-green, terracotta light cover;
- graphite, moss, restrained neon-green dark cover;
- one shared ledger/monogram geometry;
- no gradients, emoji, stock photography, glossy mockup frames, or vendor AI marks;
- Lucide icons with consistent stroke width and optical size.

- [ ] **步骤 2：编写失败的图标清单测试**

```swift
import Testing
@testable import RomeoDailyLedger

struct IconManifestTests {
    @Test func everyInterfaceIconComesFromTheApprovedLucideManifest() throws {
        let manifest = try IconManifest.load()
        #expect(Set(manifest.names) == [
            "settings", "notebook-pen", "calendar-days", "chart-no-axes-combined",
            "sparkles", "plus", "pencil", "trash-2", "download", "upload",
            "sun", "moon", "languages", "refresh-cw", "check", "x"
        ])
        #expect(manifest.license == "ISC")
    }
}
```

- [ ] **步骤 3：运行并确认失败**

```bash
xcodebuild test -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' -only-testing:RomeoDailyLedgerTests/IconManifestTests
```

Expected: FAIL because the manifest and assets do not exist.

- [ ] **步骤 4：创建可复现视觉资产**

- Draw the brand mark and both covers as authored SVG files with descriptive `<title>` elements.
- Make `Scripts/generate_app_icon.swift` use AppKit/CoreGraphics to draw the same approved geometry at 1024×1024 and generate every required macOS AppIcon PNG size; avoid downloading raster assets.
- Make `Scripts/sync_lucide_icons.sh` accept an explicit, pinned Lucide release tag, copy only the approved SVG filenames from a checked-out source directory, and write `Icons/manifest.json` containing the release, names, source URL, and ISC license.
- Preserve original Lucide paths; only normalize `currentColor`, dimensions, and accessibility metadata in the SwiftUI rendering layer.

- [ ] **步骤 5：生成并目视检查深浅两版**

```bash
swift Scripts/generate_app_icon.swift
plutil -lint RomeoDailyLedger/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
open docs/assets/cover-light.svg
open docs/assets/cover-dark.svg
```

Expected: icon catalog lint succeeds; both covers display the same brand with the approved light/dark palettes and no mixed-language UI copy.

- [ ] **步骤 6：运行清单测试**

Run the Step 3 command.

Expected: PASS, and the manifest lists exactly the approved Lucide assets.

- [ ] **步骤 7：提交**

```bash
git add Brand docs/assets Scripts/generate_app_icon.swift Scripts/sync_lucide_icons.sh RomeoDailyLedger/Resources/Assets.xcassets RomeoDailyLedgerTests/Brand/IconManifestTests.swift
git commit -m "feat: add original brand and Lucide icon assets"
```

---

## Task 5: Add open-source, privacy, and contributor documentation

**Files:**

- Create: `LICENSE`
- Create: `README.md`
- Create: `CONTRIBUTING.md`
- Create: `CODE_OF_CONDUCT.md`
- Create: `SECURITY.md`
- Create: `PRIVACY.md`
- Create: `THIRD_PARTY_NOTICES.md`
- Create: `.github/ISSUE_TEMPLATE/bug_report.yml`
- Create: `.github/ISSUE_TEMPLATE/feature_request.yml`
- Create: `.github/pull_request_template.md`
- Create: `Scripts/verify_repository_docs.sh`

- [ ] **步骤 1：编写失败的仓库文档检查**

`Scripts/verify_repository_docs.sh` must fail unless all of the following are true:

- MIT license text and the current year are present;
- README contains Chinese and English sections, build prerequisites, XcodeGen commands, screenshots for both themes, feature/non-goal lists, privacy summary, AI protocol explanation, manual update behavior, contribution links, and license attribution;
- privacy policy states local-first storage, opt-in AI transmission, Keychain secret storage, user-initiated update network access, and no telemetry/account requirement;
- security policy explains private vulnerability reporting without asking reporters to post secrets;
- third-party notice names Sparkle and Lucide with their licenses and upstream URLs;
- no real API key, ledger export, signing certificate, EdDSA private key, or developer email credential is present.

- [ ] **步骤 2：运行并确认失败**

```bash
bash Scripts/verify_repository_docs.sh
```

Expected: non-zero exit with a precise list of missing files or clauses.

- [ ] **步骤 3：编写完整双语仓库材料**

Use “罗密欧每日记账” only in the Chinese section and “Romeo Daily Ledger” only in the English section of product UI examples. README may be bilingual by section. Clearly label macOS 14+, local-first storage, editable AI drafts, protocol-based AI connections, and manual-only update checks.

- [ ] **步骤 4：运行检查**

```bash
bash Scripts/verify_repository_docs.sh
```

Expected: exit `0` with `Repository documentation verified`.

- [ ] **步骤 5：提交**

```bash
git add LICENSE README.md CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md PRIVACY.md THIRD_PARTY_NOTICES.md .github Scripts/verify_repository_docs.sh
git commit -m "docs: prepare project for open source collaboration"
```

---

## Task 6: Add reproducible CI without secrets or publishing

**Files:**

- Create: `.github/workflows/ci.yml`
- Create: `Scripts/ci_test.sh`
- Create: `Scripts/scan_for_secrets.sh`
- Create: `RomeoDailyLedgerTests/Repository/ProjectPolicyTests.swift`

- [ ] **步骤 1：编写失败的项目策略测试**

Test that:

- deployment target is macOS 14.0 or newer;
- bundle identifier and scheme are stable;
- `ci.yml` has read-only default permissions;
- pull-request CI has no release, Pages, or package write permission;
- workflows do not interpolate AI API keys, Sparkle private keys, or notarization credentials in logs;
- tracked files contain no API-key-shaped values, `.p12`, `.cer`, `.mobileprovision`, exported ledgers, or Keychain dumps.

- [ ] **步骤 2：运行并确认失败**

```bash
xcodebuild test -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' -only-testing:RomeoDailyLedgerTests/ProjectPolicyTests
```

Expected: FAIL because CI and scanners do not exist.

- [ ] **步骤 3：实现 CI 和本地同构脚本**

`Scripts/ci_test.sh` runs, in order:

```bash
xcodegen generate
xcodebuild build -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
bash Scripts/verify_repository_docs.sh
bash Scripts/scan_for_secrets.sh
git diff --check
```

`ci.yml` runs the same script on pushes and pull requests using a current macOS runner, pins action major versions, uses `permissions: contents: read`, and has no deployment job.

- [ ] **步骤 4：在本地运行完整 CI 脚本**

```bash
bash Scripts/ci_test.sh
```

Expected: all builds, tests, documentation checks, secret scans, and whitespace checks pass.

- [ ] **步骤 5：提交**

```bash
git add .github/workflows/ci.yml Scripts/ci_test.sh Scripts/scan_for_secrets.sh RomeoDailyLedgerTests/Repository/ProjectPolicyTests.swift
git commit -m "ci: verify macOS build tests and repository policy"
```

---

## Task 7: Build and validate the signed appcast release pipeline

**Files:**

- Create: `Scripts/archive_release.sh`
- Create: `Scripts/notarize_release.sh`
- Create: `Scripts/generate_appcast.sh`
- Create: `Scripts/verify_release_artifacts.sh`
- Create: `.github/workflows/release.yml`
- Create: `docs/updates/.gitkeep`
- Modify: `RomeoDailyLedger/Resources/Info.plist`
- Create: `docs/releasing.md`

- [ ] **步骤 1：编写失败的产物验证器**

`verify_release_artifacts.sh <version> <build> <archive> <appcast>` must reject artifacts unless:

- the archive contains `Romeo Daily Ledger.app` with matching marketing version and build;
- the app is Developer ID signed with hardened runtime and passes `codesign --verify --deep --strict`;
- notarization is accepted and the ticket is stapled;
- the appcast item matches the exact version, archive URL, length, minimum system version, and EdDSA signature;
- the archive URL targets `github.com/DUGUSHUANGTAN/Romeo-Daily-Ledger/releases/download/…`;
- no automatic-update preference is enabled in the built app;
- an older signed build can read the feed and validate the new signed archive in the documented end-to-end test.

- [ ] **步骤 2：针对未签名夹具运行并确认失败**

```bash
bash Scripts/verify_release_artifacts.sh 0.1.0 1 Fixtures/unsigned-release.zip Fixtures/invalid-appcast.xml
```

Expected: non-zero exit with signature, notarization, and appcast validation failures.

- [ ] **步骤 3：实现本地发布脚本**

- `archive_release.sh` runs XcodeGen, archives Release, exports a Developer ID app, and creates a versioned ZIP.
- `notarize_release.sh` uses an explicit Keychain profile name with `xcrun notarytool`; never accepts raw Apple credentials on the command line.
- `generate_appcast.sh` calls Sparkle's pinned `generate_appcast`, reads the EdDSA key from the secure release environment, and writes `docs/updates/appcast.xml`.
- `verify_release_artifacts.sh` performs all Step 1 checks and never echoes secrets.
- `Info.plist` contains only the EdDSA public key in `SUPublicEDKey`; the private key is never generated into the repository.

- [ ] **步骤 4：加入带审批门槛的发布工作流**

`release.yml` runs only from an explicit version tag or manual dispatch, requires a protected `release` environment, builds/signs/notarizes, verifies artifacts, then prepares GitHub Release and Pages appcast outputs. Configure it so repository permissions and environment approval are required before any upload step. Document every required secret name without recording secret values.

- [ ] **步骤 5：只执行演练验证**

```bash
bash Scripts/archive_release.sh --dry-run
bash Scripts/notarize_release.sh --dry-run
bash Scripts/generate_appcast.sh --dry-run
bash Scripts/verify_release_artifacts.sh --self-test
```

Expected: each script prints the exact planned commands, validates inputs, performs no upload, and exits `0`; the verifier's negative fixtures are rejected.

- [ ] **步骤 6：记录真实发布检查清单**

In `docs/releasing.md`, include version bump, changelog, full CI, archive, Developer ID signing, notarization, staple, EdDSA appcast signing, old-to-new update test, GitHub Release upload, GitHub Pages deployment, clean-machine install test, and rollback instructions. State explicitly that executing the real publish steps requires user authorization.

- [ ] **步骤 7：提交**

```bash
git add Scripts/archive_release.sh Scripts/notarize_release.sh Scripts/generate_appcast.sh Scripts/verify_release_artifacts.sh .github/workflows/release.yml docs/updates docs/releasing.md RomeoDailyLedger/Resources/Info.plist
git commit -m "build: add signed GitHub update release pipeline"
```

---

## Task 8: Run the release-readiness gate without publishing

**Files:**

- Modify: `README.md`
- Modify: `PROGRESS.md`
- Create: `docs/release-readiness.md`

- [ ] **步骤 1：运行完整本地验证套件**

```bash
bash Scripts/ci_test.sh
bash Scripts/verify_release_artifacts.sh --self-test
rg -n "SUEnableAutomaticChecks.*true|SUAutomaticallyUpdate.*true|scheduledCheckInterval|automatic-update-toggle|automatic-check-toggle" RomeoDailyLedger project.yml
git diff --check
git status --short
```

Expected:

- CI and release self-tests exit `0`;
- the forbidden automatic-update scan returns no matches;
- `git diff --check` returns no output;
- `git status --short` contains only intentional readiness documentation changes before the final commit.

- [ ] **步骤 2：执行应用级验收测试**

In both Chinese/light and English/dark modes verify:

1. Launching the app causes no GitHub or appcast request.
2. Opening Settings causes no update request.
3. General → Software Update shows current version and one manual button.
4. Clicking that button is the first update request and opens Sparkle's foreground result UI.
5. No automatic-check setting exists.
6. `⌘,` opens Settings while no shortcut badge appears beside the sidebar settings icon.
7. All visible icons use the approved Lucide manifest.
8. Both covers and the app icon remain legible at macOS thumbnail sizes.

Record environment, build SHA, screenshots, pass/fail, and any follow-up issue in `docs/release-readiness.md`.

- [ ] **步骤 3：更新交接文档**

Update README screenshots and `PROGRESS.md` with verified commands, remaining release prerequisites, and the explicit boundary: no GitHub push, Pages configuration, or release publication has occurred.

- [ ] **步骤 4：提交**

```bash
git add README.md PROGRESS.md docs/release-readiness.md
git commit -m "docs: record release readiness verification"
```

- [ ] **步骤 5：在授权边界停止**

Report the verified local state and ask the user whether to push the branch, open a pull request, configure GitHub Pages/secrets, or prepare the first release. Do not perform any of those external actions implicitly.

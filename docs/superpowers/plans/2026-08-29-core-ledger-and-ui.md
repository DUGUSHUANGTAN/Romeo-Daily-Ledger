# 核心账本与原生 UI 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 交付无需网络即可运行的 macOS 14+ 原生账本，覆盖账目 CRUD、分类、日历、多选合计、基础统计、双主题、字体、动效和中英文。

**架构：** XcodeGen 生成单一 macOS 应用工程。SwiftUI 功能模块只通过 `LedgerRepository` 读写 SwiftData；偏好通过 `AppPreferences` 注入，界面不直接持有 `ModelContext`。

**技术栈：** Swift 6、SwiftUI、SwiftData、Swift Charts、Observation、AppStorage、XcodeGen、XCTest/Swift Testing

**代码约定：** 除非代码块另有说明，Swift Testing 文件以 `import Testing` 和 `@testable import RomeoDailyLedger` 开头；领域模型按需导入 `Foundation`、`SwiftData`，界面文件导入 `SwiftUI`。每个测试替身都放入计划列出的 `RomeoDailyLedgerTests/Support/` 文件，不依赖未定义的全局夹具。

---

## 任务 1：建立可生成、可测试的 macOS 工程

**文件：**
- 创建：`project.yml`
- 创建：`Config/Debug.xcconfig`
- 创建：`Config/Release.xcconfig`
- 创建：`RomeoDailyLedger/App/RomeoDailyLedgerApp.swift`
- 创建：`RomeoDailyLedger/App/RootView.swift`
- 创建：`RomeoDailyLedgerTests/AppLaunchTests.swift`
- 创建：`RomeoDailyLedgerUITests/AppSmokeUITests.swift`

- [ ] **步骤 1：安装并确认 XcodeGen**

运行：

```bash
command -v xcodegen || brew install xcodegen
xcodegen --version
```

预期：输出 XcodeGen 版本且退出码为 0。

- [ ] **步骤 2：编写失败的应用元数据测试**

```swift
import XCTest
@testable import RomeoDailyLedger

final class AppLaunchTests: XCTestCase {
    func testEnglishAndChineseNamesAreDefined() {
        XCTAssertEqual(AppIdentity.chineseName, "罗密欧每日记账")
        XCTAssertEqual(AppIdentity.englishName, "Romeo Daily Ledger")
    }
}
```

- [ ] **步骤 3：创建工程清单和最少应用代码**

`project.yml` 至少包含：

```yaml
name: RomeoDailyLedger
options:
  deploymentTarget:
    macOS: "14.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
    PRODUCT_BUNDLE_IDENTIFIER: com.romeoke.RomeoDailyLedger
targets:
  RomeoDailyLedger:
    type: application
    platform: macOS
    sources: [RomeoDailyLedger]
    settings:
      configs:
        Debug: Config/Debug.xcconfig
        Release: Config/Release.xcconfig
    info:
      path: RomeoDailyLedger/Resources/Info.plist
      properties:
        CFBundleDisplayName: Romeo Daily Ledger
        LSMinimumSystemVersion: "14.0"
  RomeoDailyLedgerTests:
    type: bundle.unit-test
    platform: macOS
    sources: [RomeoDailyLedgerTests]
    dependencies:
      - target: RomeoDailyLedger
  RomeoDailyLedgerUITests:
    type: bundle.ui-testing
    platform: macOS
    sources: [RomeoDailyLedgerUITests]
    dependencies:
      - target: RomeoDailyLedger
```

```swift
enum AppIdentity {
    static let chineseName = "罗密欧每日记账"
    static let englishName = "Romeo Daily Ledger"
}

@main
struct RomeoDailyLedgerApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
        Settings { Text("Settings") }
    }
}
```

- [ ] **步骤 4：生成工程并运行测试**

运行：

```bash
xcodegen generate
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' test
```

预期：`** TEST SUCCEEDED **`。

- [ ] **步骤 5：提交**

```bash
git add project.yml Config RomeoDailyLedger RomeoDailyLedgerTests RomeoDailyLedgerUITests RomeoDailyLedger.xcodeproj
git commit -m "build: scaffold macOS application"
```

## 任务 2：定义账目、分类和测试容器

**文件：**
- 创建：`RomeoDailyLedger/Domain/EntryKind.swift`
- 创建：`RomeoDailyLedger/Domain/LedgerEntry.swift`
- 创建：`RomeoDailyLedger/Domain/Category.swift`
- 创建：`RomeoDailyLedger/Domain/LedgerDraft.swift`
- 创建：`RomeoDailyLedger/Infrastructure/Persistence/ModelContainerFactory.swift`
- 测试：`RomeoDailyLedgerTests/Domain/LedgerModelTests.swift`

- [ ] **步骤 1：编写失败的金额与默认分类测试**

```swift
@Test func draftRejectsZeroAmount() {
    let draft = LedgerDraft(kind: .expense, amountText: "0", categoryID: nil, note: "", occurredAt: .now)
    #expect(throws: LedgerDraft.ValidationError.invalidAmount) { try draft.validatedAmount() }
}

@Test func entryKeepsDecimalPrecision() {
    let entry = LedgerEntry(kind: .expense, amount: Decimal(string: "0.10")!, categoryID: UUID(), note: "", occurredAt: .now)
    #expect(entry.amount == Decimal(string: "0.10")!)
}
```

- [ ] **步骤 2：运行测试并确认类型缺失**

运行：

```bash
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' test -only-testing:RomeoDailyLedgerTests/LedgerModelTests
```

预期：编译失败，提示 `LedgerDraft` 或 `LedgerEntry` 未定义。

- [ ] **步骤 3：实现最少领域类型**

```swift
enum EntryKind: String, Codable, CaseIterable { case expense, income }

@Model
final class LedgerEntry {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var amount: Decimal
    var categoryID: UUID
    var note: String
    var occurredAt: Date
    var createdAt: Date
    var updatedAt: Date

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw)! }
        set { kindRaw = newValue.rawValue }
    }

    init(kind: EntryKind, amount: Decimal, categoryID: UUID, note: String, occurredAt: Date) {
        self.id = UUID(); self.kindRaw = kind.rawValue; self.amount = amount
        self.categoryID = categoryID; self.note = note; self.occurredAt = occurredAt
        self.createdAt = .now; self.updatedAt = .now
    }
}

struct LedgerDraft {
    enum ValidationError: Error { case invalidAmount }
    var kind: EntryKind; var amountText: String; var categoryID: UUID?
    var note: String; var occurredAt: Date
    func validatedAmount() throws -> Decimal {
        guard let value = Decimal(string: amountText), value > 0 else { throw ValidationError.invalidAmount }
        return value
    }
}
```

`Category.swift` 使用稳定系统键保存内置分类，显示名称只通过本地化键解析；自定义分类保存用户名称：

```swift
@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var systemKey: String?
    var customName: String?
    var iconName: String
    var colorToken: String
    var sortOrder: Int
    var isHidden: Bool

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw)! }
        set { kindRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), kind: EntryKind, systemKey: String? = nil,
         customName: String? = nil, iconName: String, colorToken: String,
         sortOrder: Int, isHidden: Bool = false) {
        self.id = id; self.kindRaw = kind.rawValue; self.systemKey = systemKey
        self.customName = customName; self.iconName = iconName
        self.colorToken = colorToken; self.sortOrder = sortOrder; self.isHidden = isHidden
    }
}
```

- [ ] **步骤 4：实现内存测试容器并运行测试**

```swift
enum ModelContainerFactory {
    static func inMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: LedgerEntry.self, Category.self, configurations: configuration)
    }
}
```

运行：同步骤 2。预期：`** TEST SUCCEEDED **`。

- [ ] **步骤 5：提交**

```bash
git add RomeoDailyLedger/Domain RomeoDailyLedger/Infrastructure/Persistence RomeoDailyLedgerTests/Domain
git commit -m "feat: add ledger domain models"
```

## 任务 3：实现仓库与内置分类播种

**文件：**
- 创建：`RomeoDailyLedger/Infrastructure/Persistence/LedgerRepository.swift`
- 创建：`RomeoDailyLedger/Infrastructure/Persistence/SwiftDataLedgerRepository.swift`
- 创建：`RomeoDailyLedger/Infrastructure/Persistence/DefaultCategorySeeder.swift`
- 创建：`RomeoDailyLedgerTests/Support/TestRepository.swift`
- 创建：`RomeoDailyLedgerTests/Support/RepositoryDoubles.swift`
- 测试：`RomeoDailyLedgerTests/Persistence/LedgerRepositoryTests.swift`

- [ ] **步骤 1：编写失败的播种、回退和编辑测试**

```swift
@Test func seederCreatesRequiredExpenseCategories() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    let names = try await repository.categories(kind: .expense).map(\.systemKey)
    #expect(Set(names.compactMap { $0 }).isSuperset(of: ["clothing", "food", "housing", "transport", "entertainment", "other"]))
}

@Test func saveWithoutCategoryFallsBackToOther() async throws {
    let repository = try TestRepository.make()
    try await repository.seedDefaultsIfNeeded()
    let saved = try await repository.insert(LedgerDraft(kind: .expense, amountText: "12.50", categoryID: nil, note: "Lunch", occurredAt: .now))
    #expect(try await repository.category(id: saved.categoryID)?.systemKey == "other")
}
```

- [ ] **步骤 2：运行定向测试确认失败**

运行：

```bash
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' test -only-testing:RomeoDailyLedgerTests/LedgerRepositoryTests
```

预期：仓库协议和实现缺失导致失败。

- [ ] **步骤 3：定义窄接口并实现 SwiftData 仓库**

```swift
@MainActor
protocol LedgerRepository {
    func seedDefaultsIfNeeded() async throws
    func insert(_ draft: LedgerDraft) async throws -> LedgerEntry
    func update(id: UUID, draft: LedgerDraft) async throws
    func delete(ids: Set<UUID>) async throws
    func entries(in interval: DateInterval) async throws -> [LedgerEntry]
    func categories(kind: EntryKind) async throws -> [Category]
    func category(id: UUID) async throws -> Category?
}
```

实现时，`insert` 在 `categoryID == nil` 时查询同类型 `systemKey == "other"`，并在一次 `ModelContext.save()` 中写入。

首次播种固定创建支出分类“衣、食、住、行、娱乐、其他”（系统键 `clothing/food/housing/transport/entertainment/other`）和收入分类“工资、奖金、理财、退款、其他”（系统键 `salary/bonus/investment/refund/other`）。中文、英文显示名来自本地化资源；系统键不随语言变化。

`TestRepository.make()` 必须用 `ModelContainerFactory.inMemory()` 构造真实 `SwiftDataLedgerRepository`。`RecordingLedgerRepository` 完整实现协议并记录 `insert/update/delete` 调用；`FailingLedgerRepository` 的写操作抛出固定 `TestRepositoryError.forcedFailure`，读操作返回空集合。后续计划中的状态模型测试统一复用这两个显式替身。

- [ ] **步骤 4：运行仓库测试和全部测试**

运行：

```bash
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' test -only-testing:RomeoDailyLedgerTests/LedgerRepositoryTests
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' test
```

预期：两条命令均 `** TEST SUCCEEDED **`。

- [ ] **步骤 5：提交**

```bash
git add RomeoDailyLedger/Infrastructure/Persistence RomeoDailyLedgerTests/Persistence RomeoDailyLedgerTests/Support
git commit -m "feat: add local ledger repository"
```

## 任务 4：实现快速记账与编辑状态模型

**文件：**
- 创建：`RomeoDailyLedger/Features/Ledger/LedgerViewModel.swift`
- 创建：`RomeoDailyLedger/Features/Ledger/EntryEditorViewModel.swift`
- 测试：`RomeoDailyLedgerTests/Ledger/LedgerViewModelTests.swift`

- [ ] **步骤 1：编写失败的保存、保留输入和编辑测试**

```swift
@Test func successfulSaveClearsTextButKeepsDate() async throws {
    let repository = RecordingLedgerRepository()
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let model = LedgerViewModel(repository: repository)
    model.draft = LedgerDraft(kind: .expense, amountText: "20", categoryID: nil, note: "Dinner", occurredAt: date)
    try await model.save()
    #expect(model.draft.amountText.isEmpty)
    #expect(model.draft.occurredAt == date)
}

@Test func failedSavePreservesInput() async {
    let model = LedgerViewModel(repository: FailingLedgerRepository())
    model.draft.amountText = "20"
    await #expect(throws: Error.self) { try await model.save() }
    #expect(model.draft.amountText == "20")
}
```

- [ ] **步骤 2：运行测试确认失败**

运行：指定 `LedgerViewModelTests`。预期：`LedgerViewModel` 缺失。

- [ ] **步骤 3：实现最少状态模型**

```swift
@Observable @MainActor
final class LedgerViewModel {
    var draft = LedgerDraft(kind: .expense, amountText: "", categoryID: nil, note: "", occurredAt: .now)
    var errorMessage: String?
    private let repository: LedgerRepository

    init(repository: LedgerRepository) { self.repository = repository }

    func save() async throws {
        do {
            _ = try await repository.insert(draft)
            draft.amountText = ""; draft.note = ""; draft.categoryID = nil
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
            throw error
        }
    }
}
```

- [ ] **步骤 4：运行定向和全部测试**

预期：全部成功。

- [ ] **步骤 5：提交**

```bash
git add RomeoDailyLedger/Features/Ledger RomeoDailyLedgerTests/Ledger
git commit -m "feat: add ledger entry state models"
```

## 任务 5：实现多选合计、批量删除和撤销

**文件：**
- 创建：`RomeoDailyLedger/Features/Ledger/SelectionSummary.swift`
- 创建：`RomeoDailyLedger/Features/Ledger/DeletionUndoCoordinator.swift`
- 测试：`RomeoDailyLedgerTests/Ledger/SelectionSummaryTests.swift`

- [ ] **步骤 1：编写失败的混合合计测试**

```swift
@Test func mixedSelectionReportsIncomeExpenseAndNet() {
    let entries = [fixture(.expense, "30"), fixture(.income, "100"), fixture(.expense, "20")]
    let result = SelectionSummary(entries: entries)
    #expect(result.income == 100)
    #expect(result.expense == 50)
    #expect(result.net == 50)
}
```

- [ ] **步骤 2：运行测试确认失败**

运行：指定 `SelectionSummaryTests`。预期：类型缺失。

- [ ] **步骤 3：实现纯值合计和可恢复删除快照**

```swift
struct SelectionSummary: Equatable {
    let income: Decimal; let expense: Decimal
    var net: Decimal { income - expense }
    init(entries: [LedgerEntry]) {
        income = entries.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }
        expense = entries.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }
    }
}
```

删除协调器在删除前复制可重建字段，撤销时通过仓库重新插入；撤销窗口结束后丢弃内存快照。

- [ ] **步骤 4：补充全选、取消和撤销测试并运行**

预期：定向与全部测试成功。

- [ ] **步骤 5：提交**

```bash
git add RomeoDailyLedger/Features/Ledger RomeoDailyLedgerTests/Ledger
git commit -m "feat: add selection totals and undo deletion"
```

## 任务 6：实现 Taste 驱动的设计系统、Lucide 和应用壳

**文件：**
- 创建：`RomeoDailyLedger/DesignSystem/AppTheme.swift`
- 创建：`RomeoDailyLedger/DesignSystem/AppTypography.swift`
- 创建：`RomeoDailyLedger/DesignSystem/MotionPolicy.swift`
- 创建：`RomeoDailyLedger/DesignSystem/LucideIcon.swift`
- 创建：`RomeoDailyLedger/App/AppDependencies.swift`
- 修改：`RomeoDailyLedger/App/RootView.swift`
- 创建：`RomeoDailyLedger/App/AppCommands.swift`
- 测试：`RomeoDailyLedgerTests/DesignSystem/DesignSystemTests.swift`

- [ ] **步骤 1：读取并执行 Taste Skill 的预检**

完整读取 `/Users/romeoke/.codex/skills/design-taste-frontend/SKILL.md`，将其适用于原生 SwiftUI：保留已批准的暖纸浅色、石墨深色、克制层级和非模板化品牌表达。记录预检结论到 `docs/design/taste-preflight.md`。

- [ ] **步骤 2：编写失败的主题和动效测试**

```swift
@Test func darkThemeUsesApprovedCanvas() { #expect(AppTheme.dark.canvas.hex == "161B21") }
@Test func reduceMotionOverridesSlider() {
    #expect(MotionPolicy(slider: 100, systemReduceMotion: true).effectiveIntensity == 0)
}
```

- [ ] **步骤 3：实现令牌和一级导航**

```swift
enum SidebarDestination: String, CaseIterable, Identifiable {
    case ledger, aiAssistant, calendar, insights, settings
    var id: Self { self }
}

struct AppTheme {
    let canvas: AppColor; let chrome: AppColor; let primaryText: AppColor; let accent: AppColor
    static let light = AppTheme(canvas: .hex("FFFDF8"), chrome: .hex("EEE7DA"), primaryText: .hex("28241E"), accent: .hex("E89769"))
    static let dark = AppTheme(canvas: .hex("161B21"), chrome: .hex("101318"), primaryText: .hex("EEF1F4"), accent: .hex("B8E78C"))
}
```

`RootView` 使用 `NavigationSplitView`；设置项显示 Lucide 齿轮但不显示 `⌘,` 字样。

- [ ] **步骤 4：加入 Lucide 固定版本和许可证**

将实际使用的 SVG 复制到 `RomeoDailyLedger/Resources/Lucide/`，创建 `ThirdPartyNotices/Lucide.txt`，测试每个导航目标都能解析图标资源。

- [ ] **步骤 5：运行设计系统测试和应用构建**

```bash
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' test -only-testing:RomeoDailyLedgerTests/DesignSystemTests
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -configuration Debug build
```

预期：测试与构建成功。

- [ ] **步骤 6：提交**

```bash
git add RomeoDailyLedger/DesignSystem RomeoDailyLedger/App RomeoDailyLedger/Resources/Lucide ThirdPartyNotices docs/design
git commit -m "feat: add branded app shell and design system"
```

## 任务 7：实现记账 UI、编辑器与日历

**文件：**
- 创建：`RomeoDailyLedger/Features/Ledger/LedgerView.swift`
- 创建：`RomeoDailyLedger/Features/Ledger/QuickEntryView.swift`
- 创建：`RomeoDailyLedger/Features/Ledger/EntryListView.swift`
- 创建：`RomeoDailyLedger/Features/Ledger/EntryEditorView.swift`
- 创建：`RomeoDailyLedger/Features/Ledger/SelectionSummaryBar.swift`
- 创建：`RomeoDailyLedger/Features/Calendar/CalendarViewModel.swift`
- 创建：`RomeoDailyLedger/Features/Calendar/CalendarView.swift`
- 测试：`RomeoDailyLedgerTests/Calendar/CalendarViewModelTests.swift`
- UI 测试：`RomeoDailyLedgerUITests/LedgerFlowUITests.swift`

- [ ] **步骤 1：编写失败的月份与日期区间测试**

```swift
@Test func selectedDayUsesLocalCalendarBoundaries() {
    let calendar = Calendar(identifier: .gregorian)
    let model = CalendarViewModel(calendar: calendar, timeZone: TimeZone(identifier: "Asia/Shanghai")!)
    let interval = model.dayInterval(containing: ISO8601DateFormatter().date(from: "2026-08-29T12:00:00+08:00")!)
    #expect(interval.duration == 86_400)
}
```

- [ ] **步骤 2：实现日历纯逻辑并验证测试**

`CalendarViewModel` 只生成月份网格和 `DateInterval`，账目查询继续由仓库执行。

- [ ] **步骤 3：编写 UI 测试再接线界面**

```swift
func testCreateEditAndSelectEntry() {
    let app = XCUIApplication(); app.launchArguments = ["--ui-testing"] ; app.launch()
    app.buttons["新建账目"].click()
    app.textFields["金额"].typeText("12.50")
    app.buttons["保存账目"].click()
    XCTAssertTrue(app.staticTexts["$12.50"].exists)
}
```

- [ ] **步骤 4：实现可访问性标识、编辑和多选栏**

所有按钮和图标提供本地化 `accessibilityLabel`；列表双击或上下文菜单打开编辑器；多选栏显示三项合计。

- [ ] **步骤 5：运行 UI、定向和全部测试**

预期：全部成功。

- [ ] **步骤 6：提交**

```bash
git add RomeoDailyLedger/Features/Ledger RomeoDailyLedger/Features/Calendar RomeoDailyLedgerTests/Calendar RomeoDailyLedgerUITests
git commit -m "feat: add ledger and calendar interfaces"
```

## 任务 8：实现基础统计

**文件：**
- 创建：`RomeoDailyLedger/Features/Insights/InsightsAggregator.swift`
- 创建：`RomeoDailyLedger/Features/Insights/InsightsViewModel.swift`
- 创建：`RomeoDailyLedger/Features/Insights/InsightsView.swift`
- 测试：`RomeoDailyLedgerTests/Insights/InsightsAggregatorTests.swift`

- [ ] **步骤 1：编写失败的月度聚合测试**

```swift
@Test func aggregatesMonthlyTotalsAndCategoryShares() {
    let report = InsightsAggregator().makeReport(entries: fixtures, interval: august2026)
    #expect(report.income == 1000)
    #expect(report.expense == 250)
    #expect(report.balance == 750)
    #expect(report.categoryTotals[foodID] == 150)
}
```

- [ ] **步骤 2：实现无 UI 的纯聚合器并运行测试**

聚合器输入 `[LedgerEntry]` 和 `DateInterval`，输出不可变 `InsightsReport`；不得读写仓库。

- [ ] **步骤 3：用 Swift Charts 接线统计页**

空数据显示本地化空状态；图表同时提供文字摘要和 VoiceOver 描述。

- [ ] **步骤 4：运行测试与构建**

预期：定向测试和 Debug 构建成功。

- [ ] **步骤 5：提交**

```bash
git add RomeoDailyLedger/Features/Insights RomeoDailyLedgerTests/Insights
git commit -m "feat: add monthly ledger insights"
```

## 任务 9：实现通用、外观和完整本地化设置

**文件：**
- 创建：`RomeoDailyLedger/Infrastructure/Preferences/AppPreferences.swift`
- 创建：`RomeoDailyLedger/Features/Settings/SettingsRootView.swift`
- 创建：`RomeoDailyLedger/Features/Settings/GeneralSettingsView.swift`
- 创建：`RomeoDailyLedger/Features/Settings/AppearanceSettingsView.swift`
- 创建：`RomeoDailyLedger/Features/Settings/CategoryManagementView.swift`
- 创建：`RomeoDailyLedger/Resources/Localizable.xcstrings`
- 测试：`RomeoDailyLedgerTests/Settings/AppPreferencesTests.swift`
- UI 测试：`RomeoDailyLedgerUITests/LocalizationUITests.swift`

- [ ] **步骤 1：编写失败的默认值测试**

```swift
@Test func defaultsMatchSpecification() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let preferences = AppPreferences(defaults: defaults)
    #expect(preferences.currencyCode == "USD")
    #expect(preferences.motionIntensity == 50)
    #expect(preferences.themeMode == .system)
}
```

- [ ] **步骤 2：实现偏好仓库和三种字体/主题**

`AppPreferences` 对 UserDefaults 提供强类型属性；语言切换重建根视图环境，不翻译备注和自定义分类。

- [ ] **步骤 3：创建 String Catalog 并补齐全部系统文案**

为 `zh-Hans` 与 `en` 提供应用名称、导航、设置、内置分类、空状态、错误和按钮翻译。协议名和模型 ID 使用原值。

- [ ] **步骤 4：编写并运行“不混用语言”的 UI 测试**

中文模式断言不存在 `Ledger`、`Settings`、`General`、`Appearance`；英文模式断言不存在对应中文系统导航词。

- [ ] **步骤 5：运行全部测试并提交里程碑**

```bash
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' test
git add RomeoDailyLedger RomeoDailyLedgerTests RomeoDailyLedgerUITests
git commit -m "feat: complete offline ledger milestone"
```

预期：`** TEST SUCCEEDED **`，应用在断网环境可完成全部核心流程。

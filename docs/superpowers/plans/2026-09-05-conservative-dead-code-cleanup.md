# V1.1.0 保守死代码清理实施计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 删除经证明无生产调用的 V1.1.0 代码，不改变 UI 或功能。

**架构：** 保留当前 SwiftUI 视图结构和数据流，仅从现有类型中去掉无调用分支、无调用 API 及其专用测试。小步删除后立即编译，不引入新抽象。

**技术栈：** Swift 6、SwiftUI、AppKit、Swift Testing、Xcodebuild。

---

## 文件范围

- `RomeoDailyLedger/App/RootView.swift`：删除未实例化的占位页和 subtitle API。
- `RomeoDailyLedger/Features/Settings/SettingsRootView.swift`：删除未使用的独立设置窗口分支。
- `RomeoDailyLedger/Features/Settings/{AISettingsView,CategoryManagementView,GeneralSettingsView,AppearanceSettingsView}.swift`：删除旧排序入口、无用策略和参数。
- `RomeoDailyLedger/Features/Ledger/LedgerFormatting.swift`：删除未调用的旧中文分类格式化。
- `RomeoDailyLedger/Infrastructure/Preferences/AppLocalization.swift`：删除恒等的 `userContent`。
- `RomeoDailyLedger/DesignSystem/AppTheme.swift`：删除无用颜色令牌。
- 相关测试和 `Localizable.xcstrings`：只删除专用断言与死 subtitle/placeholder 键。

### 任务 1：锁定死代码契约

- [ ] **步骤 1：运行现有相关测试，记录基线**

```bash
xcodebuild test -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -only-testing:RomeoDailyLedgerTests/DesignSystemTests -only-testing:RomeoDailyLedgerTests/AppPreferencesTests -only-testing:RomeoDailyLedgerTests/LocalizationTests CODE_SIGNING_ALLOWED=NO
```

预期：清理相关基线测试通过。

- [ ] **步骤 2：用 `rg` 确认所有候选项只有定义或测试调用**

```bash
rg -n 'DestinationPlaceholder|localizedSubtitle|standalone|WindowAppearanceBridge|moveModels\(|CategoryManagementPolicy|userContent\(|selectionForeground' RomeoDailyLedger RomeoDailyLedgerTests
```

预期：不出现候选 API 的有效生产调用。

### 任务 2：最小删除生产死代码

- [ ] **步骤 1：删除根视图与设置的不可达分支**

`SettingsRootView` 保留单一构造路径：

```swift
struct SettingsRootView: View {
    let dependencies: AppDependencies
    var keyboardScope: Binding<SidebarKeyboardScope>?

    var body: some View {
        SettingsContentView(dependencies: dependencies, keyboardScope: keyboardScope)
    }
}
```

同时整体删除 `DestinationPlaceholder`、`localizedSubtitle`、`subtitle`、`WindowAppearanceBridge` 和 `AppearanceHostingView`。

- [ ] **步骤 2：删除无调用 API 和参数**

删除 `moveModels(from:to:)`、CategoryManagementView 的 `move(kind:source:destination:)`、两个 `IndexSet` 排序重载、`CategoryManagementPolicy`、`userContent`、旧 `categoryName(_:)`、`GeneralSettingsView.repository`、`AppearanceSettingsView.systemReduceMotion`、`AppTheme.selectionForeground` 和 `divider`。

- [ ] **步骤 3：编译验证删除未破坏生产代码**

```bash
xcodebuild build -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -configuration Debug CODE_SIGNING_ALLOWED=NO
```

预期：`BUILD SUCCEEDED`。

### 任务 3：删除对应测试和资源

- [ ] **步骤 1：删除只验证已删 API 的断言**

从 `AppPreferencesTests`中保留当前拖拽排序测试，删除 `IndexSet` 旧排序测试；从 `DesignSystemTests`、`LocalizationTests`、`LedgerRepositoryTests` 删除仅对应死 API 的断言。

- [ ] **步骤 2：删除无调用的 `nav.*.subtitle` 和 `placeholder.futureFeature` 本地化项**

用 `plutil -lint RomeoDailyLedger/Resources/Localizable.xcstrings` 确认资源仍为有效 JSON property list。

- [ ] **步骤 3：重跑相关测试**

```bash
xcodebuild test -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -only-testing:RomeoDailyLedgerTests/DesignSystemTests -only-testing:RomeoDailyLedgerTests/AppPreferencesTests -only-testing:RomeoDailyLedgerTests/LocalizationTests -only-testing:RomeoDailyLedgerTests/LedgerRepositoryTests CODE_SIGNING_ALLOWED=NO
```

预期：没有由本轮清理导致的新失败。

### 任务 4：最终验证和打开 Debug App

- [ ] **步骤 1：静态分析和 Debug 构建**

```bash
xcodebuild analyze -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -configuration Debug CODE_SIGNING_ALLOWED=NO
xcodebuild build -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -configuration Debug -derivedDataPath .build/v1.1.0-debug
```

预期：`ANALYZE SUCCEEDED` 和 `BUILD SUCCEEDED`。

- [ ] **步骤 2：只启动当前 V1.1.0 Debug App**

```bash
open .build/v1.1.0-debug/Build/Products/Debug/RomeoDailyLedger.app
```

预期：用户可直接肉眼验收，不生成 DMG，不推送。

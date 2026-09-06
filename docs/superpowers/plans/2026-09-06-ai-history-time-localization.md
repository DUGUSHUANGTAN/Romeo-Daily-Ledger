# AI 分析历史时间语言切换实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** AI 分析历史列表的时间随软件内简体中文、繁体中文、英语设置即时切换。

**架构：** 保留现有原生 `Date.FormatStyle`，只把 Locale 的数据源从可能滞后的环境值改为该界面已经绑定的 `AppPreferences.language`。通过源码回归测试锁定该响应式依赖，避免引入新格式化器或重建历史窗口。

**技术栈：** Swift 6、SwiftUI、Foundation `Date.FormatStyle`、Swift Testing

---

### 任务 1：绑定 AI 历史时间到偏好语言

**文件：**
- 修改：`RomeoDailyLedger/Features/AI/AILedgerAssistantView.swift:609`
- 测试：`RomeoDailyLedgerTests/DesignSystem/DesignSystemTests.swift:209`

- [x] **步骤 1：编写失败的测试**

在 `visibleDatesFollowTheSelectedAppLanguage()` 中读取 AI 助手源码并增加：

```swift
let aiAssistant = try String(
    contentsOf: root.appendingPathComponent("RomeoDailyLedger/Features/AI/AILedgerAssistantView.swift"),
    encoding: .utf8
)
#expect(aiAssistant.contains(".locale(preferences.language.locale)"))
```

- [x] **步骤 2：运行测试验证失败**

运行：

```bash
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -configuration Debug -derivedDataPath /tmp/RomeoDailyLedger-DerivedData test '-only-testing:RomeoDailyLedgerTests/DesignSystemTests/visibleDatesFollowTheSelectedAppLanguage()'
```

预期：FAIL，源码尚为 `.locale(language.locale)`。

- [x] **步骤 3：实施最小修改**

将 AI 分析历史行的时间文本改为：

```swift
Text(
    item.createdAt,
    format: .dateTime.year().month().day().hour().minute().locale(preferences.language.locale)
)
```

- [x] **步骤 4：运行聚焦测试和全量单元测试**

运行：

```bash
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -configuration Debug -derivedDataPath /tmp/RomeoDailyLedger-DerivedData test '-only-testing:RomeoDailyLedgerTests/DesignSystemTests/visibleDatesFollowTheSelectedAppLanguage()'
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -configuration Debug -derivedDataPath /tmp/RomeoDailyLedger-DerivedData test -only-testing:RomeoDailyLedgerTests
```

预期：两条命令均以 `** TEST SUCCEEDED **` 结束。

- [x] **步骤 5：打开 Debug App 验收**

```bash
open -n '/tmp/RomeoDailyLedger-DerivedData/Build/Products/Debug/Romeo Daily Ledger.app'
```

预期：AI 分析历史列表时间随软件内语言切换，不制作 release。

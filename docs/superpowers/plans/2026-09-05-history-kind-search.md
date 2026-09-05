# 历史账目类型搜索实现计划

> **面向 AI 代理的工作者：** 使用 superpowers:executing-plans 内联执行，步骤使用复选框跟踪。

**目标：** 让历史搜索按当前语言匹配收入和支出。

**架构：** 复用 `HistorySearchIndex` 和现有本地化文案，只增加两个搜索字段，不添加 UI 或依赖。

**技术栈：** Swift、SwiftUI、Swift Testing

---

### 任务 1：本地化类型搜索

**文件：**
- 修改：`RomeoDailyLedger/Features/Calendar/CalendarViewModel.swift`
- 修改：`RomeoDailyLedger/Features/Ledger/LedgerView.swift`
- 测试：`RomeoDailyLedgerTests/Calendar/CalendarViewModelTests.swift`

- [x] 在 HistoryLedgerTests 增加三语收入/支出搜索失败测试。
- [x] 运行 HistoryLedgerTests，确认当前实现无法按类型筛选。
- [x] 为 `HistorySearchIndex` 增加收入、支出显示名称并参与现有包含匹配；由 `HistoryView` 传入当前语言文案。
- [x] 运行 HistoryLedgerTests 和完整单元测试。
- [x] 构建并打开 V1.1.0 Debug App；不打包、不上传。

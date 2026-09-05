# V1.1.0 P0/P1 修复实施计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复全部已确认 P0/P1 问题。

**架构：** 复用 Keychain、SettingsStore、StorageCoordinator 和现有 ViewModel，每个修复只增加一个最小边界检查或状态。

**技术栈：** Swift 6、SwiftUI、SwiftData、Security、Swift Testing/XCTest。

---

### 任务 1：API Key 脱敏与迁移

- [ ] 在 `AppPreferencesTests` 和 `StorageTests` 增加 JSON 不含密钥、每预设密钥恢复、旧 JSON 迁移测试并确认失败。
- [ ] 向 `AppPreferences` 注入现有 `AIKeychainStoring`，加载时迁移/恢复，保存时先写 Keychain 再写脱敏 JSON。
- [ ] 删除 `StorageCoordinator` 中 Keychain → JSON 的反向迁移。
- [ ] 运行 `AppPreferencesTests` 和 `StorageTests`。

### 任务 2：安全提交数据目录迁移

- [ ] 增加 active bookmark 保存失败时旧目录仍存在的测试并确认失败。
- [ ] 将 `prepareBeforeOpeningContainer` 改为不在 migrator 内删除源目录，bookmark 成功后再尽力清理。
- [ ] 运行 `StorageTests`。

### 任务 3：CSV 重复表头

- [ ] 增加重复表头返回 `malformedCSV` 的测试并确认失败。
- [ ] 在建立表头字典前增加唯一性 guard。
- [ ] 运行 `DataTransferTests`。

### 任务 4：日历日期同步

- [ ] 增加切换年月后 `selectedDate` 处于目标月的测试并确认失败。
- [ ] `select(year:month:)` 同步更新两个日期。
- [ ] 运行 `CalendarViewModelTests`。

### 任务 5：避免重复全表扫描

- [ ] 增加同一 repository 重复 seed 不再重新正规化的测试并确认失败。
- [ ] 在 `SwiftDataLedgerRepository` 中增加成功后置位的 `didSeedDefaults` 布尔值。
- [ ] 运行 `LedgerRepositoryTests`。

### 任务 6：验证与 Debug App

- [ ] 运行全部单元测试与 `xcodebuild analyze`。
- [ ] 构建 `.build/v1.1.0-debug` 并确认版本 1.1.0。
- [ ] 关闭旧实例，只打开当前 V1.1.0 Debug App。

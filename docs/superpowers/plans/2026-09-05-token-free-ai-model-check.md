# AI 模型零 Token 检测实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框跟踪进度。

**目标：** 用不生成文本的模型列表请求检测预设，缓存 10 分钟，并提供检测全部模型按钮。

**架构：** `AIClient` 负责构造并解析 `GET /models`；`AIModelPreset` 保存最近检测时间；`AISettingsView` 决定自动检测的缓存命中和手动强制检测。沿用现有连接状态和并发任务组，不新增依赖或状态层级。

**技术栈：** Swift、SwiftUI、Foundation URLSession、Swift Testing

---

### 任务 1：零 Token 模型检测请求

**文件：**
- 修改：`RomeoDailyLedger/Infrastructure/AI/AIClient.swift`
- 测试：`RomeoDailyLedgerTests/AI/AIClientTests.swift`

- [ ] 编写失败测试：断言连接检测请求为 `GET /v1/models`、没有请求体，并分别覆盖目标模型存在与不存在。
- [ ] 运行 `xcodebuild test -quiet -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -only-testing:RomeoDailyLedgerTests/AIClientTests CODE_SIGNING_ALLOWED=NO`，确认旧 POST 实现导致失败。
- [ ] 最少实现：验证 URL、模型和密钥；请求 Base URL 的 `models`；解码 `{"data":[{"id":"ledger"}]}` 并要求包含配置的模型 ID。
- [ ] 重跑 AIClientTests，确认通过且检测路径不调用生成接口。

### 任务 2：10 分钟缓存

**文件：**
- 修改：`RomeoDailyLedger/Infrastructure/AI/AIProtocol.swift`
- 修改：`RomeoDailyLedger/Features/Settings/AISettingsView.swift`
- 测试：`RomeoDailyLedgerTests/Settings/AppPreferencesTests.swift`

- [ ] 编写失败测试：旧 JSON 缺少检测时间仍可解码；新预设检测时间可编码往返；缓存判断在 10 分钟内为新鲜、到达边界为过期。
- [ ] 运行对应 AppPreferencesTests，确认缺少时间字段或缓存 API 尚不存在导致失败。
- [ ] 最少实现：为预设添加 `lastConnectionCheckAt: Date?`，添加纯函数 `shouldCheck(lastCheckedAt:now:maximumAge:)`，默认最大时效 600 秒。
- [ ] 保存或编辑模型配置时清空检测时间；检测完成时同时写入状态和当前时间。
- [ ] 重跑 AppPreferencesTests，确认通过。

### 任务 3：检测全部模型按钮

**文件：**
- 修改：`RomeoDailyLedger/Features/Settings/AISettingsView.swift`
- 修改：`RomeoDailyLedger/Resources/Localizable.xcstrings`
- 测试：`RomeoDailyLedgerTests/DesignSystem/DesignSystemTests.swift`

- [ ] 编写失败的源码契约测试：模型区存在本地化“检测模型”按钮，按钮调用忽略缓存的全部检测入口。
- [ ] 运行 DesignSystemTests，确认失败。
- [ ] 最少实现：进入页面只传入过期预设；按钮传入全部预设；任一检测进行时禁用按钮；空列表时按钮禁用。
- [ ] 添加简体中文、繁体中文和英文按钮文案，保持当前设置页尺寸与结构。
- [ ] 重跑 DesignSystemTests，确认通过。

### 任务 4：完整验证与 Debug App

- [ ] 运行完整 `RomeoDailyLedgerTests`。
- [ ] 运行 `xcodebuild analyze -quiet -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger CODE_SIGNING_ALLOWED=NO`。
- [ ] 构建 Debug 到 `.build/v1.1.0-debug`，只启动当前 V1.1.0 App 供用户肉眼验收。
- [ ] 运行 `git diff --check` 并更新 `PROGRESS.md`；不打包、不上传 GitHub。

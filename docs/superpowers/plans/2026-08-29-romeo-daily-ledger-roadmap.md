# 罗密欧每日记账总实施路线图

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 按三个可独立验证的里程碑交付 macOS 14+ 原生本地记账应用、协议驱动的 AI 助手，以及安全的 GitHub 发布与手动更新能力。

**架构：** SwiftUI 功能模块通过明确的状态模型访问唯一 `LedgerRepository`，SwiftData 保存账目和分类，AppStorage 保存偏好，Keychain 保存 API 密钥。AI 和软件更新都是可拔除的边界服务，故障不得影响核心离线账本。

**技术栈：** Swift 6、SwiftUI、SwiftData、Swift Charts、Observation、Security/Keychain Services、URLSession、Sparkle 2、XcodeGen、XCTest/Swift Testing、GitHub Actions

---

## 计划文件

1. [核心账本与原生 UI 计划](./2026-08-29-core-ledger-and-ui.md)
2. [数据管理与 AI 助手计划](./2026-08-29-data-and-ai-assistant.md)
3. [手动更新、开源与发布计划](./2026-08-29-updates-open-source-release.md)

三个计划必须按顺序执行。每个计划结束时都产出可启动、可测试的应用；不得把失败测试或未接线界面留给下一个计划。

## 固定项目结构

```text
.
├── project.yml
├── Config/
│   ├── Debug.xcconfig
│   └── Release.xcconfig
├── RomeoDailyLedger/
│   ├── App/
│   ├── DesignSystem/
│   ├── Domain/
│   ├── Features/
│   │   ├── Ledger/
│   │   ├── Calendar/
│   │   ├── Insights/
│   │   ├── Settings/
│   │   └── AIAssistant/
│   ├── Infrastructure/
│   │   ├── Persistence/
│   │   ├── Preferences/
│   │   ├── Security/
│   │   ├── ImportExport/
│   │   ├── AI/
│   │   └── Updates/
│   └── Resources/
├── RomeoDailyLedgerTests/
├── RomeoDailyLedgerUITests/
├── Scripts/
├── docs/
├── .github/
└── LICENSE
```

## 文件职责

### 应用与设计系统

- `RomeoDailyLedger/App/RomeoDailyLedgerApp.swift`：应用入口、场景和依赖装配。
- `RomeoDailyLedger/App/AppDependencies.swift`：仓库、偏好、密钥、AI 和更新服务的组合根。
- `RomeoDailyLedger/App/RootView.swift`：一级导航，不承载业务规则。
- `RomeoDailyLedger/App/AppCommands.swift`：`⌘N`、`⌘,` 等命令；侧边栏不显示快捷键文字。
- `RomeoDailyLedger/DesignSystem/AppTheme.swift`：浅色、深色和主题令牌。
- `RomeoDailyLedger/DesignSystem/AppTypography.swift`：系统、衬线、圆角字体策略。
- `RomeoDailyLedger/DesignSystem/MotionPolicy.swift`：0–100 动效强度与系统减少动态效果合并规则。
- `RomeoDailyLedger/DesignSystem/LucideIcon.swift`：固定版本的 Lucide SVG 映射。

### 领域与核心功能

- `RomeoDailyLedger/Domain/LedgerEntry.swift`：SwiftData 账目模型。
- `RomeoDailyLedger/Domain/Category.swift`：SwiftData 分类模型。
- `RomeoDailyLedger/Domain/EntryKind.swift`：收入/支出枚举。
- `RomeoDailyLedger/Domain/LedgerDraft.swift`：手动与 AI 共用的可校验草稿。
- `RomeoDailyLedger/Infrastructure/Persistence/LedgerRepository.swift`：唯一账本访问协议。
- `RomeoDailyLedger/Infrastructure/Persistence/SwiftDataLedgerRepository.swift`：SwiftData 实现。
- `RomeoDailyLedger/Infrastructure/Persistence/ModelContainerFactory.swift`：生产、预览、测试容器。
- `RomeoDailyLedger/Features/Ledger/*`：录入、编辑、列表、多选与撤销。
- `RomeoDailyLedger/Features/Calendar/*`：月历、日期选择和每日汇总。
- `RomeoDailyLedger/Features/Insights/*`：只读聚合与 Swift Charts。
- `RomeoDailyLedger/Features/Settings/*`：通用、外观和 AI 三个独立分栏。

### 数据与 AI

- `RomeoDailyLedger/Infrastructure/ImportExport/CSVLedgerCodec.swift`：CSV 编解码与行错误。
- `RomeoDailyLedger/Infrastructure/ImportExport/BackupCodec.swift`：版本化 JSON 备份。
- `RomeoDailyLedger/Infrastructure/ImportExport/DataTransferService.swift`：导入预览、事务写入、恢复前快照。
- `RomeoDailyLedger/Infrastructure/Security/KeychainStore.swift`：密钥增删改查。
- `RomeoDailyLedger/Domain/AIConnection.swift`：非敏感连接配置。
- `RomeoDailyLedger/Infrastructure/AI/AIProtocolAdapter.swift`：四种协议的统一接口。
- `RomeoDailyLedger/Infrastructure/AI/*Adapter.swift`：Chat Completions、Responses、Messages、GenerateContent 适配。
- `RomeoDailyLedger/Infrastructure/AI/LedgerAnalysisChunker.swift`：稳定分批和覆盖率校验。
- `RomeoDailyLedger/Features/AIAssistant/*`：AI 记账草稿和完整账本分析。

### 更新与发布

- `RomeoDailyLedger/Infrastructure/Updates/UpdateService.swift`：Sparkle 的手动检查封装。
- `RomeoDailyLedger/Features/Settings/Updates/SoftwareUpdateSettingsView.swift`：当前版本和“检查更新”按钮。
- `Scripts/generate_appcast.sh`：签名更新包并生成 appcast。
- `.github/workflows/ci.yml`：不接触真实 API 的持续集成。
- `.github/workflows/release.yml`：签名、公证、Release、appcast 和 Pages。

## 规格覆盖矩阵

| 规格区域 | 实施位置 |
|---|---|
| 收入/支出 CRUD、任意后期编辑 | 计划 1，任务 2–5 |
| 内置/自定义分类与“其他”回退 | 计划 1，任务 2–4 |
| 日历按日期调账 | 计划 1，任务 7 |
| 多选收入/支出/净额 | 计划 1，任务 5 |
| 月度摘要、分类占比、趋势 | 计划 1，任务 8 |
| 双主题、字体、动效、双语 | 计划 1，任务 6、9 |
| 导入、导出、备份、恢复 | 计划 2，任务 1–3 |
| 多连接与钥匙串 | 计划 2，任务 4–5 |
| 四种 AI 协议 | 计划 2，任务 6–9 |
| AI 批量记账草稿 | 计划 2，任务 10 |
| 含备注完整账本分析 | 计划 2，任务 11–12 |
| 手动检查 GitHub 更新 | 计划 3，任务 1–3 |
| Lucide、应用图标、项目封面 | 计划 1，任务 6；计划 3，任务 4 |
| MIT、README、贡献与安全文档 | 计划 3，任务 5 |
| CI、签名、公证、GitHub Release | 计划 3，任务 6–8 |

## 阶段门槛

### 里程碑 1：核心离线账本

- 应用可启动。
- 收入/支出可新增、编辑、删除。
- 日历、统计、多选、分类、主题、字体、动效和双语可用。
- 无网络权限也能通过全部测试。

### 里程碑 2：数据与 AI

- CSV/JSON 往返一致。
- 密钥只在 Keychain。
- 四种协议均通过模拟服务器契约测试。
- AI 多草稿确认与完整账本覆盖率测试通过。

### 里程碑 3：可发布开源应用

- 更新只在用户点击后发起网络请求。
- 旧签名版本可以安全更新到新签名版本。
- README、MIT、隐私说明、贡献指南和发布工作流齐全。
- 发布前完整 `xcodebuild test` 为零失败。

## 全局执行规则

- 每个实现任务都执行红—绿—重构循环。
- 每个任务结束后运行该任务的定向测试，再运行相关测试套件。
- 不将真实 API Key 写入源代码、测试夹具、命令历史或 CI 日志。
- UI 工作开始前必须读取并使用 `design-taste-frontend` skill；应用图标和项目封面也遵循同一视觉系统。
- 所有图标从固定版本 Lucide SVG 生成，不使用 SF Symbols 作为交付图标。
- 未经用户再次授权，不执行 `git push`、创建 GitHub Release 或写入 GitHub Secrets。

# 罗密欧每日记账

[English](README_EN.md) | 简体中文

## 项目简介

罗密欧每日记账（Romeo Daily Ledger）是一个面向 macOS 14 及以上版本的原生记账应用项目，使用 Swift 6、SwiftUI 与 SwiftData 开发。

应用采用本地优先设计：无需账号，账目保存在 Mac 本地，适合日常快速记账与自用。

## 开发状态

V1.0.0 已实现记账、日历回看、多选汇总、分类管理、基础统计、中英文与深浅主题、AI 记账/分析、JSON/CSV 数据迁移及 GitHub 更新检查。

## 当前已有能力

- 快速新增、编辑、删除收入和支出，默认币种可在 General 中修改。
- 按日历查看账目，多选流水后计算汇总。
- 支出与收入分类、“其他”回退、月度收支、结余、趋势与分类统计。
- 浅色/深色主题、字体与动效强度设置，完整中英文界面。
- 通过 OpenAI Chat Completions 或 Responses 协议连接兼容服务；API Key 仅保存在 macOS Keychain。
- AI 自然语言记账草稿需预览确认后才保存；AI 分析需显式授权并限定日期范围。
- 从设置导入 JSON/CSV，导出 JSON/CSV；提供预览、重复项策略、币种校验和原子批量写入。
- 手动检查 GitHub Release 更新，不会自动安装。

## 技术栈

- Swift 6
- SwiftUI
- SwiftData
- XCTest 与 Swift Testing
- XcodeGen（可选，用于根据 `project.yml` 生成 Xcode 工程）

## 系统要求

- macOS 14.0 或更高版本
- 支持 Swift 6 的 Xcode 版本
- XcodeGen（仅在需要重新生成工程时使用）

## 开始使用

克隆仓库并进入项目目录：

```bash
git clone https://github.com/DUGUSHUANGTAN/Romeo-Daily-Ledger.git
cd Romeo-Daily-Ledger
```

仓库已经包含 `RomeoDailyLedger.xcodeproj`。如需根据项目配置重新生成工程，可先安装 XcodeGen，然后运行：

```bash
xcodegen generate
```

打开项目：

```bash
open RomeoDailyLedger.xcodeproj
```

在 Xcode 中选择 `RomeoDailyLedger` scheme，即可构建并运行应用。

也可以通过命令行构建：

```bash
xcodebuild build \
  -project RomeoDailyLedger.xcodeproj \
  -scheme RomeoDailyLedger \
  -destination 'platform=macOS'
```

运行测试：

```bash
xcodebuild test \
  -project RomeoDailyLedger.xcodeproj \
  -scheme RomeoDailyLedger \
  -destination 'platform=macOS'
```

## V1.0.0 Release 打包

Release 配置使用 `MARKETING_VERSION = 1.0.0` 和 `CURRENT_PROJECT_VERSION = 1`。应用名称保持“罗密欧每日记账”/“Romeo Daily Ledger”，版本号仅用于应用元数据和安装包文件名。

```bash
./scripts/build_release.sh  # 生成 Release .app
./scripts/create_dmg.sh     # 生成 DMG 和 SHA-256 校验文件
```

产物默认位于 `build/release/`：`Romeo Daily Ledger.app`、`Romeo-Daily-Ledger-1.0.0.dmg` 和对应的 `.sha256` 文件。DMG 包含应用以及指向 `/Applications` 的快捷方式。可通过 `BUILD_DIR=/path/to/output` 自定义输出目录；已有 `.app` 时可用 `SKIP_BUILD=1 ./scripts/create_dmg.sh` 跳过重新构建。

本地自用可不签名构建。公开分发时可使用 `SIGNING_IDENTITY="Developer ID Application: …" ./scripts/build_release.sh` 签名，并用 `NOTARY_PROFILE=profile SKIP_BUILD=1 ./scripts/create_dmg.sh` 公证和 staple。进入产物目录后可执行 `shasum -a 256 -c Romeo-Daily-Ledger-1.0.0.dmg.sha256` 校验下载。

安装时打开 DMG，将“Romeo Daily Ledger”拖入 Applications。未签名的自用构建首次打开可能需要在 Finder 中右键选择“打开”。

## 目录结构

```text
.
├── Config/                         # Debug 与 Release 构建配置
├── RomeoDailyLedger/
│   ├── App/                        # 应用入口与当前根视图
│   ├── Domain/                     # 流水、分类与录入草稿领域模型
│   ├── Infrastructure/Persistence/ # SwiftData 容器、默认分类与仓储实现
│   └── Resources/                  # Info.plist 等应用资源
├── RomeoDailyLedgerTests/          # 单元测试与应用名称测试
├── RomeoDailyLedgerUITests/        # UI 启动冒烟测试
├── RomeoDailyLedger.xcodeproj/     # 已生成的 Xcode 工程
└── project.yml                     # XcodeGen 项目配置
```

## 后续方向

- 可选 iCloud 同步与自动备份。
- 更多统计维度和可自定义的报表。
- 经签名、公证的公开发布流程。

## 贡献

欢迎通过 Issue 报告问题或提出建议，也欢迎提交 Pull Request。提交代码前请确保改动范围清晰，并运行现有测试。对于新增功能，建议同时补充相应测试与说明。

## 许可证

本项目采用 MIT License，详情请参阅 [LICENSE](LICENSE)。

# 罗密欧每日记账

[English](README_EN.md) | 简体中文

## 项目简介

罗密欧每日记账（Romeo Daily Ledger）是一个面向 macOS 14 及以上版本的原生记账应用项目，使用 Swift 6、SwiftUI 与 SwiftData 开发。

项目目前处于早期开发阶段。现有界面仅为显示“Romeo Daily Ledger”的应用骨架，尚不具备可供日常使用的记账流程。

## 开发状态

当前仓库已建立基础领域模型、SwiftData 仓储实现和测试框架，但仓储尚未接入 App 生命周期，录入、查询、分类管理与统计等产品界面也尚未完成。仓库已包含可直接打开的 Xcode 工程，也可以根据 `project.yml` 使用 XcodeGen 重新生成工程。

## 当前已有能力

- 区分支出（`expense`）与收入（`income`）两种流水类型。
- `LedgerEntry` 流水模型支持：
  - 使用 `Decimal` 保存金额；
  - 关联分类 ID；
  - 保存备注、发生时间、创建时间与更新时间。
- `Category` 分类模型支持：
  - 支出或收入类型；
  - 系统分类标识或自定义名称；
  - 图标、颜色、排序顺序与隐藏状态。
- `LedgerDraft` 可解析金额文本，并拒绝零值、负数和无法解析的金额。
- 提供基于 SwiftData 的内存 `ModelContainer`，目前主要用于开发与测试基础设施。
- `LedgerRepository` 与 `SwiftDataLedgerRepository` 支持流水插入、更新、批量删除、半开日期区间查询，以及按类型查询分类和查询单个分类。
- 支持幂等播种默认收支分类；录入时未选择分类，会回退到对应收支类型的 `other` 分类。
- 已有以下自动化测试：
  - 中英文应用名称校验；
  - 金额正数校验与 `Decimal` 精度校验；
  - 默认收支分类、幂等播种与未选分类回退校验；
  - 半开日期区间查询、流水更新与批量删除校验；
  - 应用启动 UI 冒烟测试。

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

脚本生成未签名归档，适合本地验收和 GitHub Release 产物准备。正式分发前应在可信构建环境中完成 Developer ID 签名与公证。脚本不会创建 GitHub Release，也不会上传文件。

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

## 路线图

以下功能尚未完成：

- [ ] 收入与支出的录入界面及完整交互
- [ ] 将 SwiftData 持久化容器与仓储接入 App 生命周期
- [ ] 流水列表、详情、编辑与删除
- [ ] 分类的创建、编辑、排序、隐藏与系统分类展示
- [ ] 收支汇总、趋势和分类统计
- [ ] 搜索、筛选与日期范围查询
- [ ] 更完整的单元测试、集成测试与 UI 测试

路线图不代表发布日期或实现顺序，实际开发计划可能调整。

## 贡献

欢迎通过 Issue 报告问题或提出建议，也欢迎提交 Pull Request。提交代码前请确保改动范围清晰，并运行现有测试。对于新增功能，建议同时补充相应测试与说明。

## 许可证

本项目采用 MIT License，详情请参阅 [LICENSE](LICENSE)。

# 罗密欧每日记账

简体中文 | [English](README_EN.md)

罗密欧每日记账（Romeo Daily Ledger）是一款原生、离线优先的 macOS 个人记账应用。无需账号，账目保存在 Mac 本地。

## 功能

- 收支录入、编辑、删除，日历回看、多选汇总和月度统计。
- 分类管理、中英文界面和跟随系统的深浅主题。
- 兼容 OpenAI Chat Completions / Responses 协议的 AI 记账与分析；API Key 保存在 macOS 钥匙串中，不会包含在账本导出文件里。
- JSON / CSV 导入导出，支持预览、重复项处理、币种校验和原子批量写入。
- 手动检查 GitHub Release 更新，不会自动安装。

## 安装

从 [GitHub Releases](https://github.com/DUGUSHUANGTAN/Romeo-Daily-Ledger/releases) 下载 DMG，打开后将 “Romeo Daily Ledger” 拖入 Applications。

V1.1.0 提供 Apple Silicon（M 系列芯片）构建。没有 Developer ID 时，首次打开可能需要在 Finder 中右键应用并选择“打开”。

## 数据保存

默认数据目录为 `~/Library/Application Support/com.romeoke.RomeoDailyLedger/`，包含 SwiftData 数据库和 `settings.json`。可在“设置 → 通用 → 数据与存储”中选择新的本地父目录；应用会在其中创建 `Romeo Daily Ledger Data`，并在下次启动前完成验证和迁移。

## 开发

- Swift 6、SwiftUI、SwiftData
- macOS 14+
- 仓库已包含 `RomeoDailyLedger.xcodeproj`；也可运行 `xcodegen generate` 重新生成。

```bash
xcodebuild test -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS'
./scripts/build_release.sh
./scripts/create_dmg.sh
```

签名与公证为可选项，分别通过 `SIGNING_IDENTITY` 和 `NOTARY_PROFILE` 提供。没有 Developer ID 时，构建脚本会对 App 做完整 ad-hoc 签名；从网络下载后首次打开可能需要在 Finder 中右键选择“打开”。

## 许可证

[MIT License](LICENSE)

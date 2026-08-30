# 罗密欧每日记账

简体中文 | [English](README_EN.md)

罗密欧每日记账（Romeo Daily Ledger）是一款原生、离线优先的 macOS 个人记账应用。无需账号，账目保存在 Mac 本地。

## 功能

- 收支录入、编辑、删除，日历回看、多选汇总和月度统计。
- 分类管理、中英文界面、深浅主题及字体与动效设置。
- 兼容 OpenAI Chat Completions / Responses 协议的 AI 记账与分析；API Key 仅存于 macOS 钥匙串，AI 草稿确认后才写入，分析前会显示并授权日期范围。
- JSON / CSV 导入导出，支持预览、重复项处理、币种校验和原子批量写入。
- 手动检查 GitHub Release 更新，不会自动安装。

## 安装

从 [GitHub Releases](https://github.com/DUGUSHUANGTAN/Romeo-Daily-Ledger/releases) 下载 DMG，打开后将 “Romeo Daily Ledger” 拖入 Applications。

V1.0.0 当前提供未签名的自用构建，首次打开时可能需要在 Finder 中右键应用并选择“打开”。可在下载目录校验安装包：

```bash
shasum -a 256 -c Romeo-Daily-Ledger-1.0.0.dmg.sha256
```

## 开发

- Swift 6、SwiftUI、SwiftData
- macOS 14+
- 仓库已包含 `RomeoDailyLedger.xcodeproj`；也可运行 `xcodegen generate` 重新生成。

```bash
xcodebuild test -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS'
./scripts/build_release.sh
./scripts/create_dmg.sh
```

签名与公证为可选项，分别通过 `SIGNING_IDENTITY` 和 `NOTARY_PROFILE` 提供。

## 许可证

[MIT License](LICENSE)

# 罗密欧每日记账

简体中文 | [English](README_EN.md)

> 原生、离线优先的 macOS 个人记账应用。无需账号，账目保存在本机。

## 项目概览

- 支持 macOS 14 及更高版本
- 基于 Swift 6、SwiftUI 和 SwiftData
- 当前 Release：v1.1.0（Apple Silicon / arm64）
- MIT License

## 功能

- 收入与支出录入、编辑和删除
- 日历回看、多选汇总和月度统计
- 自定义分类管理
- 简体中文、繁体中文和英文界面
- 跟随系统的浅色和深色主题
- 兼容 OpenAI Chat Completions / Responses 协议的 AI 记账与分析
- JSON / CSV 数据导入与导出，支持预览、重复项处理、币种校验和原子批量写入
- 手动检查 GitHub Release 更新，不会自动安装

## 下载与安装

1. 前往 [GitHub Releases](https://github.com/DUGUSHUANGTAN/Romeo-Daily-Ledger/releases) 下载最新 DMG。
2. 打开 DMG，将「Romeo Daily Ledger」拖入 Applications 文件夹。
3. 首次打开时，如果 macOS 提示无法验证开发者，请在 Finder 中右键应用并选择「打开」。

当前 Release 提供 Apple Silicon（M 系列芯片）构建。

## 数据与隐私

- 应用无需账号，账目默认保存在当前 Mac 的本地用户目录中，不会自动上传或同步。
- 默认数据目录为：

  ```text
  ~/Library/Application Support/com.romeoke.RomeoDailyLedger/
  ```

- 账本使用 SwiftData 本地数据库保存；应用设置和 API Key 保存在本地 `settings.json`，文件权限仅允许当前 macOS 用户读写。
- API Key 不会包含在 JSON / CSV 账本导出文件中。
- 只有在启用并使用 AI 功能时，相关请求才会发送到你配置的 API 地址；请同时确认对应服务商的隐私政策。
- 可在「设置 → 通用 → 数据与存储」中选择新的本地父目录。应用会创建 `Romeo Daily Ledger Data` 子目录，并在下次启动前完成验证和迁移。

## 开发

### 环境要求

- macOS 14+
- Xcode（支持 Swift 6）
- 可选：XcodeGen（用于重新生成 Xcode 项目）

仓库已包含 `RomeoDailyLedger.xcodeproj`。如需根据 `project.yml` 重新生成项目：

```bash
xcodegen generate
```

### 测试、构建与打包

```bash
# 运行单元测试和 UI 测试
xcodebuild test -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS'

# 构建 Release 版本
./scripts/build_release.sh

# 创建 DMG
./scripts/create_dmg.sh
```

签名与公证是可选项，可分别通过 `SIGNING_IDENTITY` 和 `NOTARY_PROFILE` 提供。没有 Developer ID 时，构建脚本会对 App 进行完整的 Ad Hoc 签名；从网络下载后，首次打开可能仍需在 Finder 中右键选择「打开」。

## 许可证

本项目采用 [MIT License](LICENSE) 开源。

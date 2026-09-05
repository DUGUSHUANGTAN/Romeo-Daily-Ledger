# V1.1.0 P0/P1 修复设计

## 目标

使用 Ponytail 最小改动修复已审计确认的 API Key 明文存储、数据迁移提交顺序、CSV 重复表头崩溃、日历月份与选中日期不同步、重复全表扫描五项 P0/P1 问题。

## 设计

- API Key 使用现有 Keychain：活动配置使用固定 account，模型预设使用 UUID account。JSON 始终只保存清空密钥后的配置。旧 JSON 密钥在加载时写入 Keychain，随即重写脱敏 JSON。
- 数据目录迁移先复制并校验，再保存 active bookmark，最后尝试删除旧目录。清理失败不回滚已提交的新目录。
- CSV 在构造字典前用 `Set(first).count == first.count` 拒绝重复表头。
- 日历选择年月时，将 `displayedMonth` 和 `selectedDate` 同步设为目标月首日。
- Repository 使用单个内存布尔值保证 seed/日期正规化每次启动只执行一次；失败时不置位，允许重试。

## 边界

不改 UI、不新增依赖、不改 AI 请求内容、不打包、不上传 GitHub。

## 验证

每项先添加失败测试，再做最小实现；最后运行全部单元测试、静态分析和 Debug 构建，只打开 V1.1.0 Debug App。

# 数据管理与 AI 助手实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在不破坏离线账本的前提下，交付 CSV/JSON 数据管理、Keychain 多连接、四种协议适配、AI 多草稿记账和包含备注的完整账本分析。

**架构：** 数据导入导出只通过 `LedgerRepository` 事务写入；密钥只通过 `KeychainStore` 读取。四种协议适配器统一输出 `LedgerDraftBatch` 或 `AnalysisPassResult`，AI 功能状态永不直接访问 SwiftData。

**技术栈：** Swift 6、Foundation、SwiftData、Security、URLSession、UniformTypeIdentifiers、XCTest/Swift Testing

**代码约定：** Swift Testing 文件以 `import Testing` 和 `@testable import RomeoDailyLedger` 开头。复用计划 1 的 `RecordingLedgerRepository`；本计划新增的 `.fixture()`、`fixture(_:)`、`HTTPURLResponse.ok`、`InMemorySnapshotStore`、`StubAIClient` 和 `RecordingAIClient` 都必须在下列任务明确创建的 Support 文件中实现，测试不得引用隐式或未定义夹具。

---

## 任务 1：实现版本化备份结构和 JSON 往返

**文件：**
- 创建：`RomeoDailyLedger/Infrastructure/ImportExport/BackupDocument.swift`
- 创建：`RomeoDailyLedger/Infrastructure/ImportExport/BackupCodec.swift`
- 创建：`RomeoDailyLedgerTests/Support/DataFixtures.swift`
- 测试：`RomeoDailyLedgerTests/ImportExport/BackupCodecTests.swift`

- [ ] **步骤 1：编写失败的完整往返和敏感字段排除测试**

```swift
@Test func backupRoundTripPreservesLedgerData() throws {
    let document = BackupDocument.fixture()
    let encoded = try BackupCodec().encode(document)
    let decoded = try BackupCodec().decode(encoded)
    #expect(decoded == document)
}

@Test func backupNeverContainsSecrets() throws {
    let data = try BackupCodec().encode(.fixture())
    let text = String(decoding: data, as: UTF8.self)
    #expect(!text.localizedCaseInsensitiveContains("apiKey"))
    #expect(!text.contains("sk-"))
}
```

- [ ] **步骤 2：运行测试验证类型缺失**

运行：

```bash
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' test -only-testing:RomeoDailyLedgerTests/BackupCodecTests
```

预期：编译失败，提示 `BackupDocument` 未定义。

- [ ] **步骤 3：实现固定 schemaVersion 的 Codable 文档**

```swift
struct BackupDocument: Codable, Equatable {
    static let currentSchemaVersion = 1
    let schemaVersion: Int
    let exportedAt: Date
    let currencyCode: String
    let categories: [CategoryRecord]
    let entries: [LedgerEntryRecord]
}

struct BackupCodec {
    private let encoder: JSONEncoder = { let value = JSONEncoder(); value.dateEncodingStrategy = .iso8601; value.outputFormatting = [.sortedKeys]; return value }()
    private let decoder: JSONDecoder = { let value = JSONDecoder(); value.dateDecodingStrategy = .iso8601; return value }()
    func encode(_ document: BackupDocument) throws -> Data { try encoder.encode(document) }
    func decode(_ data: Data) throws -> BackupDocument {
        let value = try decoder.decode(BackupDocument.self, from: data)
        guard value.schemaVersion == BackupDocument.currentSchemaVersion else { throw BackupError.unsupportedVersion(value.schemaVersion) }
        return value
    }
}
```

`DataFixtures.swift` 提供固定 UUID、固定 ISO 8601 时间、两个分类和三条账目的 `BackupDocument.fixture()`；不得使用 `.now`，以保证编码输出稳定。

- [ ] **步骤 4：运行定向测试和提交**

预期：测试成功。

```bash
git add RomeoDailyLedger/Infrastructure/ImportExport RomeoDailyLedgerTests/ImportExport RomeoDailyLedgerTests/Support/DataFixtures.swift
git commit -m "feat: add versioned ledger backups"
```

## 任务 2：实现 CSV 编解码和导入预览

**文件：**
- 创建：`RomeoDailyLedger/Infrastructure/ImportExport/CSVLedgerCodec.swift`
- 创建：`RomeoDailyLedger/Infrastructure/ImportExport/ImportPreview.swift`
- 测试：`RomeoDailyLedgerTests/ImportExport/CSVLedgerCodecTests.swift`

- [ ] **步骤 1：编写失败的引号、换行、错误行和双语表头测试**

```swift
@Test func decodesQuotedNoteAndReportsInvalidAmount() throws {
    let csv = "发生时间,类型,金额,分类,备注\n2026-08-29T12:00:00+08:00,支出,18.00,食,\"午饭,咖啡\"\n2026-08-29T13:00:00+08:00,支出,abc,食,错误"
    let preview = try CSVLedgerCodec().preview(Data(csv.utf8), locale: Locale(identifier: "zh-Hans"))
    #expect(preview.validRows.count == 1)
    #expect(preview.invalidRows.first?.line == 3)
}
```

- [ ] **步骤 2：运行测试确认失败**

运行：指定 `CSVLedgerCodecTests`。预期：类型缺失。

- [ ] **步骤 3：实现 RFC 4180 兼容解析和确定性导出**

```swift
struct ImportPreview {
    let validRows: [LedgerEntryRecord]
    let invalidRows: [ImportRowError]
    let missingCategories: Set<String>
}

struct ImportRowError: Equatable {
    let line: Int
    let field: String
    let messageKey: String
}
```

编码列固定为发生时间、类型、金额、分类、备注、创建时间、修改时间；金额始终使用点号小数，日期使用 ISO 8601。

- [ ] **步骤 4：运行中文、英文和往返测试**

预期：定向测试成功，导出后再导入得到相同记录。

- [ ] **步骤 5：提交**

```bash
git add RomeoDailyLedger/Infrastructure/ImportExport RomeoDailyLedgerTests/ImportExport
git commit -m "feat: add CSV import preview and export"
```

## 任务 3：实现事务导入、恢复前快照和设置 UI

**文件：**
- 创建：`RomeoDailyLedger/Infrastructure/ImportExport/DataTransferService.swift`
- 创建：`RomeoDailyLedger/Features/Settings/DataManagementView.swift`
- 创建：`RomeoDailyLedgerTests/Support/ImportExportDoubles.swift`
- 测试：`RomeoDailyLedgerTests/ImportExport/DataTransferServiceTests.swift`
- UI 测试：`RomeoDailyLedgerUITests/DataManagementUITests.swift`

- [ ] **步骤 1：编写失败的无部分写入测试**

```swift
@Test func invalidImportDoesNotPartiallyWrite() async throws {
    let repository = RecordingLedgerRepository()
    let service = DataTransferService(repository: repository, snapshotStore: InMemorySnapshotStore())
    await #expect(throws: ImportError.self) { try await service.importRows([.validFixture(), .invalidFixture()]) }
    #expect(repository.inserted.isEmpty)
}
```

- [ ] **步骤 2：实现预校验、分类映射和单事务提交**

`DataTransferService` 在调用仓库前验证全部行；缺失分类要求调用者显式选择“创建自定义分类”或“映射到其他”。恢复顺序为：生成当前快照 → 校验备份 → 单事务替换。

`ImportExportDoubles.swift` 实现 `InMemorySnapshotStore`、合法/非法 `LedgerEntryRecord` 夹具和可回滚事务仓库；测试必须同时断言异常前后快照完全相同。

- [ ] **步骤 3：接入系统文件选择器和预览页**

使用 `fileImporter`、`fileExporter` 和 `UTType`；所有入口只出现在“设置 → 通用 → 数据”。

- [ ] **步骤 4：运行定向、UI 和全部测试**

预期：失败行不写入，恢复失败后原账本仍完整。

- [ ] **步骤 5：提交**

```bash
git add RomeoDailyLedger/Infrastructure/ImportExport RomeoDailyLedger/Features/Settings RomeoDailyLedgerTests/ImportExport RomeoDailyLedgerTests/Support/ImportExportDoubles.swift RomeoDailyLedgerUITests
git commit -m "feat: add transactional data management"
```

## 任务 4：实现 KeychainStore

**文件：**
- 创建：`RomeoDailyLedger/Infrastructure/Security/KeychainStore.swift`
- 创建：`RomeoDailyLedger/Infrastructure/Security/SecItemClient.swift`
- 测试：`RomeoDailyLedgerTests/Security/KeychainStoreTests.swift`

- [ ] **步骤 1：编写失败的保存、替换、读取和删除测试**

```swift
@Test func keyCanBeReplacedAndDeleted() throws {
    let client = InMemorySecItemClient()
    let store = KeychainStore(service: "tests", client: client)
    try store.save("first", account: "connection-1")
    try store.save("second", account: "connection-1")
    #expect(try store.read(account: "connection-1") == "second")
    try store.delete(account: "connection-1")
    #expect(try store.read(account: "connection-1") == nil)
}
```

- [ ] **步骤 2：定义可替换的 SecItem 客户端并实现 KeychainStore**

```swift
protocol SecItemClient {
    func copyMatching(_ query: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    func add(_ attributes: CFDictionary) -> OSStatus
    func update(_ query: CFDictionary, attributes: CFDictionary) -> OSStatus
    func delete(_ query: CFDictionary) -> OSStatus
}
```

错误映射不得包含密钥值；日志只允许连接 ID 和 OSStatus。

- [ ] **步骤 3：运行测试并扫描敏感字符串**

```bash
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' test -only-testing:RomeoDailyLedgerTests/KeychainStoreTests
rg -n 'sk-[A-Za-z0-9]|api[_-]?key\s*=' RomeoDailyLedger RomeoDailyLedgerTests && exit 1 || true
```

预期：测试成功且扫描无匹配。

- [ ] **步骤 4：提交**

```bash
git add RomeoDailyLedger/Infrastructure/Security RomeoDailyLedgerTests/Security
git commit -m "feat: store AI credentials in Keychain"
```

## 任务 5：实现多连接配置和 AI 设置界面

**文件：**
- 创建：`RomeoDailyLedger/Domain/AIConnection.swift`
- 创建：`RomeoDailyLedger/Domain/AIProtocolKind.swift`
- 创建：`RomeoDailyLedger/Infrastructure/Preferences/AIConnectionStore.swift`
- 创建：`RomeoDailyLedger/Features/Settings/AISettingsViewModel.swift`
- 创建：`RomeoDailyLedger/Features/Settings/AISettingsView.swift`
- 测试：`RomeoDailyLedgerTests/Settings/AIConnectionStoreTests.swift`

- [ ] **步骤 1：编写失败的非敏感序列化测试**

```swift
@Test func connectionSerializationContainsNoSecret() throws {
    let connection = AIConnection(displayName: "Primary", protocolKind: .chatCompletions, baseURL: URL(string: "https://example.test/v1")!, modelID: "model-a", keychainAccount: "uuid")
    let text = String(decoding: try JSONEncoder().encode(connection), as: UTF8.self)
    #expect(!text.localizedCaseInsensitiveContains("apiKey"))
}
```

- [ ] **步骤 2：实现协议枚举与连接模型**

```swift
enum AIProtocolKind: String, Codable, CaseIterable {
    case chatCompletions, responses, messages, generateContent
}

struct AIConnection: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var protocolKind: AIProtocolKind
    var baseURL: URL
    var modelID: String
    var keychainAccount: String
}
```

- [ ] **步骤 3：实现设置表单**

界面字段只显示连接名称、协议、Base URL、API 密钥、模型 ID、测试连接、删除密钥；不得展示厂家按钮或模型推荐。

- [ ] **步骤 4：运行测试与提交**

```bash
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' test -only-testing:RomeoDailyLedgerTests/AIConnectionStoreTests
git add RomeoDailyLedger/Domain RomeoDailyLedger/Infrastructure/Preferences RomeoDailyLedger/Features/Settings RomeoDailyLedgerTests/Settings
git commit -m "feat: add protocol-based AI connections"
```

## 任务 6：定义 AI 契约、错误和模拟传输

**文件：**
- 创建：`RomeoDailyLedger/Infrastructure/AI/AIProtocolAdapter.swift`
- 创建：`RomeoDailyLedger/Infrastructure/AI/AITransport.swift`
- 创建：`RomeoDailyLedger/Infrastructure/AI/AIError.swift`
- 创建：`RomeoDailyLedger/Infrastructure/AI/AIResponseModels.swift`
- 创建：`RomeoDailyLedgerTests/Support/AIFixtures.swift`
- 创建：`RomeoDailyLedgerTests/Fixtures/AI/`
- 测试：`RomeoDailyLedgerTests/AI/AIContractTests.swift`

- [ ] **步骤 1：编写失败的统一草稿验证测试**

```swift
@Test func invalidAmountNeverBecomesLedgerDraft() {
    let response = RemoteDraft(kind: "expense", amount: "abc", category: "食", occurredAt: nil, note: "午饭", needsReview: false)
    #expect(throws: AIError.invalidResponse) { try response.validated(localDate: .now, categoryResolver: .fixture()) }
}
```

- [ ] **步骤 2：定义协议接口**

```swift
protocol AIProtocolAdapter {
    func makeDraftRequest(context: DraftRequestContext) throws -> URLRequest
    func parseDraftResponse(data: Data, response: HTTPURLResponse) throws -> LedgerDraftBatch
    func makeAnalysisRequest(context: AnalysisRequestContext) throws -> URLRequest
    func parseAnalysisResponse(data: Data, response: HTTPURLResponse) throws -> AnalysisPassResult
}
```

`AITransport` 只负责 URLSession、取消、超时和 HTTP 状态；适配器负责协议形状。

`AIFixtures.swift` 提供固定请求上下文、分类解析器、`HTTPURLResponse.ok`、按文件名加载黄金 JSON 的 `fixture(_:)`、`StubAIClient` 与 `RecordingAIClient`。四种协议的成功、401、404、429、500、空候选和畸形响应 JSON 全部放入 `RomeoDailyLedgerTests/Fixtures/AI/`，不得把真实密钥写入夹具。

- [ ] **步骤 3：实现统一错误映射**

`AIError` 必须区分 `.unauthorized`、`.invalidBaseURL`、`.modelNotFound`、`.rateLimited`、`.insufficientBalance`、`.timedOut`、`.serviceUnavailable`、`.invalidResponse`、`.cancelled`。

- [ ] **步骤 4：运行契约测试并提交**

```bash
git add RomeoDailyLedger/Infrastructure/AI RomeoDailyLedgerTests/AI RomeoDailyLedgerTests/Support/AIFixtures.swift RomeoDailyLedgerTests/Fixtures/AI
git commit -m "feat: define AI protocol contracts"
```

## 任务 7：实现 Chat Completions 和 Responses 适配器

**文件：**
- 创建：`RomeoDailyLedger/Infrastructure/AI/ChatCompletionsAdapter.swift`
- 创建：`RomeoDailyLedger/Infrastructure/AI/ResponsesAdapter.swift`
- 测试：`RomeoDailyLedgerTests/AI/OpenAIStyleAdapterTests.swift`

- [ ] **步骤 1：为两个协议编写黄金 JSON 测试**

```swift
@Test func chatCompletionsParsesToolArguments() throws {
    let data = fixture("chat-completions-draft-success.json")
    let batch = try ChatCompletionsAdapter().parseDraftResponse(data: data, response: .ok)
    #expect(batch.entries.count == 2)
}

@Test func responsesParsesStructuredOutput() throws {
    let data = fixture("responses-draft-success.json")
    let batch = try ResponsesAdapter().parseDraftResponse(data: data, response: .ok)
    #expect(batch.entries.first?.amountText == "18.00")
}
```

- [ ] **步骤 2：运行测试确认失败并实现最少解析**

请求必须带模型 ID、结构化 schema、用户输入和最少上下文；API Key 只进入 Authorization 头。

- [ ] **步骤 3：添加 401、404、429、500 和畸形响应测试**

预期：全部映射到稳定 `AIError`，错误文本不包含响应头中的密钥。

- [ ] **步骤 4：运行测试并提交**

```bash
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' test -only-testing:RomeoDailyLedgerTests/OpenAIStyleAdapterTests
git add RomeoDailyLedger/Infrastructure/AI RomeoDailyLedgerTests/AI
git commit -m "feat: add chat and responses adapters"
```

## 任务 8：实现 Messages 适配器

**文件：**
- 创建：`RomeoDailyLedger/Infrastructure/AI/MessagesAdapter.swift`
- 测试：`RomeoDailyLedgerTests/AI/MessagesAdapterTests.swift`

- [ ] **步骤 1：编写工具输入解析和鉴权头测试**

```swift
@Test func requestUsesMessagesHeadersWithoutLeakingKeyIntoBody() throws {
    let request = try MessagesAdapter().makeDraftRequest(context: .fixture(apiKey: "secret"))
    #expect(request.value(forHTTPHeaderField: "x-api-key") == "secret")
    #expect(!String(decoding: request.httpBody!, as: UTF8.self).contains("secret"))
}
```

- [ ] **步骤 2：实现请求、响应和错误映射**

使用强制账目提取工具 schema；解析 `tool_use.input` 为统一批次。

- [ ] **步骤 3：运行成功、拒绝、限流和畸形测试**

预期：定向测试成功。

- [ ] **步骤 4：提交**

```bash
git add RomeoDailyLedger/Infrastructure/AI RomeoDailyLedgerTests/AI
git commit -m "feat: add messages protocol adapter"
```

## 任务 9：实现 GenerateContent 适配器

**文件：**
- 创建：`RomeoDailyLedger/Infrastructure/AI/GenerateContentAdapter.swift`
- 测试：`RomeoDailyLedgerTests/AI/GenerateContentAdapterTests.swift`

- [ ] **步骤 1：编写 schema、URL 和响应候选测试**

```swift
@Test func requestAppendsModelToConfiguredBaseURL() throws {
    let request = try GenerateContentAdapter().makeDraftRequest(context: .fixture(baseURL: "https://example.test/v1beta", modelID: "model-a"))
    #expect(request.url?.path.hasSuffix("/models/model-a:generateContent") == true)
}
```

- [ ] **步骤 2：实现请求和 JSON 文本提取**

API Key 使用该协议的请求头；本地仍执行相同草稿 schema 与业务校验。

- [ ] **步骤 3：运行候选为空、安全阻止和畸形 JSON 测试**

预期：定向测试成功。

- [ ] **步骤 4：提交**

```bash
git add RomeoDailyLedger/Infrastructure/AI RomeoDailyLedgerTests/AI
git commit -m "feat: add generate content adapter"
```

## 任务 10：实现 AI 批量记账草稿流程

**文件：**
- 创建：`RomeoDailyLedger/Features/AIAssistant/AIAssistantViewModel.swift`
- 创建：`RomeoDailyLedger/Features/AIAssistant/AIEntryView.swift`
- 创建：`RomeoDailyLedger/Features/AIAssistant/DraftCardView.swift`
- 测试：`RomeoDailyLedgerTests/AIAssistant/AIEntryFlowTests.swift`
- UI 测试：`RomeoDailyLedgerUITests/AIEntryUITests.swift`

- [ ] **步骤 1：编写失败的“确认前不写入”测试**

```swift
@Test func generatedDraftsAreNotPersistedUntilConfirmed() async throws {
    let repository = RecordingLedgerRepository()
    let model = AIAssistantViewModel(client: StubAIClient(batch: .twoEntries), repository: repository)
    await model.generateDrafts(from: "午饭 18，地铁 3")
    #expect(repository.inserted.isEmpty)
    try await model.confirmDrafts()
    #expect(repository.inserted.count == 2)
}
```

- [ ] **步骤 2：实现请求状态和一次格式重试**

状态为 `idle/loading/drafts/error`；格式异常只自动重试一次，其他错误不重试；取消保留原始输入。

- [ ] **步骤 3：实现可编辑草稿卡和统一确认**

每张卡可编辑类型、金额、分类、日期、时间和备注，也可移除；`needsReview` 使用图标和文字提示，不只用颜色。

- [ ] **步骤 4：运行模型、UI 和全部测试并提交**

```bash
git add RomeoDailyLedger/Features/AIAssistant RomeoDailyLedgerTests/AIAssistant RomeoDailyLedgerUITests
git commit -m "feat: add AI-assisted entry drafts"
```

## 任务 11：实现完整账本稳定分批与覆盖率校验

**文件：**
- 创建：`RomeoDailyLedger/Infrastructure/AI/LedgerAnalysisChunker.swift`
- 创建：`RomeoDailyLedger/Infrastructure/AI/AnalysisCoverage.swift`
- 测试：`RomeoDailyLedgerTests/AI/LedgerAnalysisChunkerTests.swift`

- [ ] **步骤 1：编写失败的无遗漏、无重复和含备注测试**

```swift
@Test func chunkingCoversEveryEntryExactlyOnceAndIncludesNotes() throws {
    let entries = (0..<501).map(LedgerEntryRecord.fixture)
    let chunks = LedgerAnalysisChunker(maxEntriesPerChunk: 100).chunks(entries.sorted { $0.id.uuidString < $1.id.uuidString })
    let flattened = chunks.flatMap(\.entries)
    #expect(Set(flattened.map(\.id)).count == 501)
    #expect(flattened.count == 501)
    #expect(flattened.allSatisfy { !$0.note.isEmpty })
}
```

- [ ] **步骤 2：实现稳定排序、批次 ID 和覆盖率断言**

```swift
struct AnalysisCoverage {
    let sourceIDs: Set<UUID>
    let processedIDs: Set<UUID>
    func validate() throws {
        guard sourceIDs == processedIDs else { throw AIError.incompleteAnalysis }
    }
}
```

- [ ] **步骤 3：补充重复 ID、批次失败和取消测试**

任一批次失败时最终状态必须为“不完整”，不得进入完整结论展示。

- [ ] **步骤 4：运行测试并提交**

```bash
git add RomeoDailyLedger/Infrastructure/AI RomeoDailyLedgerTests/AI
git commit -m "feat: add complete-ledger analysis chunking"
```

## 任务 12：实现账目分析 UI、授权和隐私回归

**文件：**
- 创建：`RomeoDailyLedger/Features/AIAssistant/AIAnalysisViewModel.swift`
- 创建：`RomeoDailyLedger/Features/AIAssistant/AIAnalysisView.swift`
- 创建：`RomeoDailyLedger/Features/Settings/AIAccessConsentView.swift`
- 测试：`RomeoDailyLedgerTests/AIAssistant/AIAnalysisFlowTests.swift`
- UI 测试：`RomeoDailyLedgerUITests/AIAnalysisUITests.swift`

- [ ] **步骤 1：编写失败的授权与全字段发送测试**

```swift
@Test func analysisRequiresConsentAndSendsAllEntriesWithNotes() async throws {
    let model = AIAnalysisViewModel(consent: false, repository: FixtureRepository(entries: .threeWithNotes), client: RecordingAIClient())
    await #expect(throws: AIError.consentRequired) { try await model.analyze("分析消费") }
    model.consent = true
    try await model.analyze("分析消费")
    #expect(model.processedEntryCount == 3)
}
```

- [ ] **步骤 2：实现首次授权文案和默认关闭偏好**

授权明确列出日期、金额、类型、分类、全部备注、远端费用与隐私；取消不发出请求。

- [ ] **步骤 3：实现分析进度、取消和结果元数据**

结果必须显示数据范围、总记录数、处理记录数、是否分批和连接名称；分析视图不提供任何修改/删除账目动作。

- [ ] **步骤 4：添加序列化与日志敏感信息扫描**

```bash
rg -n 'apiKey|authorization|x-api-key' RomeoDailyLedger/Infrastructure/ImportExport RomeoDailyLedger/Domain | tee /tmp/romeo-secret-scan.txt
test ! -s /tmp/romeo-secret-scan.txt
```

预期：备份/导出/领域序列化目录无密钥字段。

- [ ] **步骤 5：运行全部测试并提交里程碑**

```bash
xcodebuild -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger -destination 'platform=macOS' test
git add RomeoDailyLedger RomeoDailyLedgerTests RomeoDailyLedgerUITests
git commit -m "feat: complete data and AI milestone"
```

预期：`** TEST SUCCEEDED **`；拔掉网络后核心账本测试仍成功。

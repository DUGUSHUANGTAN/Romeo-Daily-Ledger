import SwiftUI
import UniformTypeIdentifiers

struct DataSettingsView: View {
    let repository: LedgerRepository
    let storage: StorageCoordinator
    let language: AppLanguage
    let currencyCode: String
    @State private var service: LedgerTransferService?
    @State private var exportData: Data?
    @State private var exportType: UTType = .json
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var preview: LedgerTransferPreview?
    @State private var importedRecords: [LedgerTransferRecord] = []
    @State private var importError: String?
    @State private var strategy: LedgerDuplicateStrategy = .skipDuplicates
    @State private var showingEraseConfirmation = false
    @State private var eraseMessage: String?

    var body: some View {
        Form {
            Section(AppLocalization.text("settings.data.export.title", language: language)) {
                Text(AppLocalization.text("settings.data.export.help", language: language))
                    .foregroundStyle(.secondary)
                HStack {
                    Button(AppLocalization.text("settings.data.export.json", language: language)) { Task { await prepareExport(.json) } }
                        .accessibilityIdentifier("data-export-json")
                    Button(AppLocalization.text("settings.data.export.csv", language: language)) { Task { await prepareExport(.csv) } }
                        .accessibilityIdentifier("data-export-csv")
                }
            }
            Section(AppLocalization.text("settings.data.import.title", language: language)) {
                Text(AppLocalization.text("settings.data.import.help", language: language)).foregroundStyle(.secondary)
                Button(AppLocalization.text("settings.data.import.button", language: language)) { showImporter = true }
                    .accessibilityIdentifier("data-import-button")
                if let preview { previewView(preview) }
                if let importError { Text(importError).foregroundStyle(.red).accessibilityIdentifier("data-import-error") }
            }
            Section {
                Button(AppLocalization.text("settings.storage.erase", language: language), role: .destructive) {
                    showingEraseConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .accessibilityValue("destructive")
                .accessibilityIdentifier("settings-erase-all")
                if let eraseMessage { Text(eraseMessage).foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(AppLocalization.text("settings.data.title", language: language))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-data")
        .fileExporter(isPresented: $showExporter, document: TransferDocument(data: exportData ?? Data()), contentType: exportType, defaultFilename: exportType == .json ? "ledger.json" : "ledger.csv") { result in
            if case .failure(let error) = result,
               (error as NSError).code != NSUserCancelledError {
                importError = AppLocalization.text("settings.data.error.export", language: language)
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .commaSeparatedText]) { result in
            guard case .success(let url) = result else {
                if case .failure(let error) = result,
                   (error as NSError).code != NSUserCancelledError {
                    importError = AppLocalization.text("settings.data.error.import", language: language)
                }
                return
            }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let format: LedgerTransferService.Format = url.pathExtension.lowercased() == "csv" ? .csv : .json
                guard let service else { return }
                let records = try service.decode(data: data, format: format)
                try service.validateCurrency(records, expected: currencyCode)
                importedRecords = records
                preview = try LedgerTransferCodec.preview(records)
                importError = nil
            } catch {
                importError = localizedTransferError(error)
                preview = nil
                importedRecords = []
            }
        }
        .task {
            service = LedgerTransferService(repository: repository)
            prepareUITestPreviewIfNeeded()
        }
        .confirmationDialog(AppLocalization.text("settings.storage.eraseConfirm", language: language), isPresented: $showingEraseConfirmation, titleVisibility: .visible) {
            Button(AppLocalization.text("settings.storage.erase", language: language), role: .destructive) {
                Task {
                    do {
                        try await repository.deleteAllEntries()
                        try storage.removeManagedMigrationStaging()
                        eraseMessage = nil
                    } catch { eraseMessage = error.localizedDescription }
                }
            }
            Button(AppLocalization.text("button.cancel", language: language), role: .cancel) {}
        }
    }

    @ViewBuilder private func previewView(_ value: LedgerTransferPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.text("settings.data.import.preview.title", language: language)).font(.headline)
            Text("\(AppLocalization.text("settings.data.import.preview.total", language: language)): \(value.totalRecords)")
            Text("\(AppLocalization.text("settings.data.import.preview.income", language: language)): \(value.incomeCount)")
            Text("\(AppLocalization.text("settings.data.import.preview.expense", language: language)): \(value.expenseCount)")
            if let range = value.dateRange {
                Text("\(AppLocalization.text("settings.data.import.preview.dateRange", language: language)): \(format(range.start)) – \(format(range.end))")
            }
            if !value.categoryCounts.isEmpty {
                Text(AppLocalization.text("settings.data.import.preview.categories", language: language))
                ForEach(value.categoryCounts.keys.sorted(), id: \.self) { key in
                    Text("\(AppLocalization.categoryName(systemKey: key, language: language)): \(value.categoryCounts[key, default: 0])")
                        .foregroundStyle(.secondary)
                }
            }
            Picker(AppLocalization.text("settings.data.import.strategy", language: language), selection: $strategy) {
                Text(AppLocalization.text("settings.data.import.skipDuplicates", language: language)).tag(LedgerDuplicateStrategy.skipDuplicates)
                Text(AppLocalization.text("settings.data.import.keepBoth", language: language)).tag(LedgerDuplicateStrategy.keepBoth)
            }
            .pickerStyle(.segmented)
            Button(AppLocalization.text("settings.data.import.confirm", language: language)) { Task { await importEntries() } }
                .accessibilityIdentifier("data-import-confirm")
            Button(AppLocalization.text("button.cancel", language: language)) { preview = nil; importedRecords = [] }
                .accessibilityIdentifier("data-import-cancel")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("data-import-preview")
    }

    private func prepareExport(_ format: LedgerTransferService.Format) async {
        guard let service else { return }
        do { exportType = format == .json ? .json : .commaSeparatedText; exportData = try await service.exportData(format: format, currencyCode: currencyCode); showExporter = true }
        catch { importError = AppLocalization.text("settings.data.error.export", language: language) }
    }

    private func importEntries() async {
        guard let service else { return }
        do {
            let ids = Set(try await repository.entries(in: DateInterval(start: .distantPast, end: .distantFuture)).map(\.id))
            let resolution = LedgerTransferCodec.resolveDuplicates(importedRecords, existingIDs: ids, strategy: strategy)
            try service.validateCurrency(resolution.imported, expected: currencyCode)
            var drafts: [LedgerDraft] = []
            for record in resolution.imported { drafts.append(try await service.draft(for: record)) }
            _ = try await repository.insert(drafts)
            preview = nil; importedRecords = []; importError = nil
        } catch { importError = localizedTransferError(error) }
    }

    private func format(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().locale(language.locale))
    }

    private func localizedTransferError(_ error: Error) -> String {
        guard let transferError = error as? LedgerTransferError else {
            return AppLocalization.text("settings.data.error.import", language: language)
        }
        switch transferError {
        case .currencyMismatch(let expected, let actual):
            return AppLocalization.format("settings.data.error.currencyMismatch", language: language, actual, expected)
        case .missingField(let field):
            return AppLocalization.format("settings.data.error.missingField", language: language, field)
        case .invalidAmount:
            return AppLocalization.text("settings.data.error.invalidAmount", language: language)
        case .invalidDate:
            return AppLocalization.text("settings.data.error.invalidDate", language: language)
        case .invalidKind:
            return AppLocalization.text("settings.data.error.invalidKind", language: language)
        case .malformedCSV:
            return AppLocalization.text("settings.data.error.malformedCSV", language: language)
        case .invalidData:
            return AppLocalization.text("settings.data.error.invalidData", language: language)
        }
    }

    private func prepareUITestPreviewIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing-data-preview"), preview == nil else { return }
        let records = [
            LedgerTransferRecord(
                id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                kind: .expense,
                amount: 12,
                currencyCode: currencyCode,
                categoryKey: "food",
                note: "UI preview",
                occurredAt: .now
            )
        ]
        importedRecords = records
        preview = try? LedgerTransferCodec.preview(records)
    }
}

struct TransferDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

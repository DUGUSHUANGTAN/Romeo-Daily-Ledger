import SwiftUI
import UniformTypeIdentifiers

struct DataSettingsView: View {
    let repository: LedgerRepository
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
        }
        .formStyle(.grouped)
        .navigationTitle(AppLocalization.text("settings.data.title", language: language))
        .accessibilityIdentifier("settings-data")
        .fileExporter(isPresented: $showExporter, document: TransferDocument(data: exportData ?? Data()), contentType: exportType, defaultFilename: exportType == .json ? "ledger.json" : "ledger.csv") { _ in }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .commaSeparatedText]) { result in
            guard case .success(let url) = result else { return }
            do {
                let data = try Data(contentsOf: url)
                let format: LedgerTransferService.Format = url.pathExtension.lowercased() == "csv" ? .csv : .json
                let records = try LedgerTransferCodec.preview(format == .json ? LedgerTransferCodec.json.decode([LedgerTransferRecord].self, from: data) : LedgerTransferCodec.csv.decode([LedgerTransferRecord].self, from: data))
                importedRecords = format == .json ? try LedgerTransferCodec.json.decode([LedgerTransferRecord].self, from: data) : try LedgerTransferCodec.csv.decode([LedgerTransferRecord].self, from: data)
                preview = records; importError = nil
            } catch { importError = error.localizedDescription; preview = nil }
        }
        .task { service = LedgerTransferService(repository: repository) }
    }

    @ViewBuilder private func previewView(_ value: LedgerTransferPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.text("settings.data.import.preview.title", language: language)).font(.headline)
            Text("\(AppLocalization.text("settings.data.import.preview.total", language: language)): \(value.totalRecords)")
            Text("\(AppLocalization.text("settings.data.import.preview.income", language: language)): \(value.incomeCount)")
            Text("\(AppLocalization.text("settings.data.import.preview.expense", language: language)): \(value.expenseCount)")
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
    }

    private func prepareExport(_ format: LedgerTransferService.Format) async {
        guard let service else { return }
        do { exportType = format == .json ? .json : .commaSeparatedText; exportData = try await service.exportData(format: format, currencyCode: currencyCode); showExporter = true }
        catch { importError = error.localizedDescription }
    }

    private func importEntries() async {
        guard let service else { return }
        do {
            let ids = Set(try await repository.entries(in: DateInterval(start: .distantPast, end: .distantFuture)).map(\.id))
            let resolution = LedgerTransferCodec.resolveDuplicates(importedRecords, existingIDs: ids, strategy: strategy)
            for record in resolution.imported { try await repository.insert(try await service.draft(for: record)) }
            preview = nil; importedRecords = []
        } catch { importError = error.localizedDescription }
    }
}

struct TransferDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

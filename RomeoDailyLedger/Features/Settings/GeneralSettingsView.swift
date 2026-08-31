import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var preferences: AppPreferences
    let storage: StorageCoordinator
    let repository: LedgerRepository
    @State private var showingUpdateCheck = false
    @State private var showingEraseConfirmation = false
    @State private var storageMessage: String?
    @State private var eraseMessage: String?
    private let commonCurrencies = ["CNY", "USD", "EUR", "GBP", "JPY", "HKD"]

    var body: some View {
        Form {
            Section(AppLocalization.text("settings.general.regional", language: preferences.language)) {
                Picker(AppLocalization.text("settings.general.currency", language: preferences.language), selection: $preferences.currencyCode) {
                    ForEach(commonCurrencies, id: \.self) { Text($0).tag($0) }
                    if !commonCurrencies.contains(preferences.currencyCode) { Text(preferences.currencyCode).tag(preferences.currencyCode) }
                }.frame(maxWidth: 220)
                TextField("Custom 3-letter code", text: $preferences.currencyCode).frame(maxWidth: 180).accessibilityIdentifier("settings-currency")
                Picker(AppLocalization.text("settings.general.language", language: preferences.language), selection: $preferences.language) {
                    Text(AppLocalization.text("language.zhHans", language: preferences.language)).tag(AppLanguage.simplifiedChinese)
                    Text(AppLocalization.text("language.en", language: preferences.language)).tag(AppLanguage.english)
                }.pickerStyle(.segmented).frame(maxWidth: 300).accessibilityIdentifier("settings-language")
            }
            Section("Data & Storage") {
                Text(storage.activeDirectory.path).textSelection(.enabled)
                if storage.pendingDirectory != nil { Text("Quit and migrate on next launch").foregroundStyle(.secondary) }
                HStack {
                    Button("Change Location…", action: chooseLocation)
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([storage.activeDirectory]) }
                    Button("Restore Default") { storage.restoreDefaultOnNextLaunch() }
                }
                if let storageMessage { Text(storageMessage).foregroundStyle(.red) }
            }
            Section {
                Button("Erase All Entries", role: .destructive) { showingEraseConfirmation = true }
                if let eraseMessage { Text(eraseMessage).foregroundStyle(.red) }
            }
            Section(AppLocalization.text("settings.update.section", language: preferences.language)) {
                Button(AppLocalization.text("settings.update.check", language: preferences.language)) { showingUpdateCheck = true }
            }
        }
        .formStyle(.grouped).navigationTitle(AppLocalization.text("settings.general.title", language: preferences.language)).padding(24)
        .accessibilityIdentifier("settings-general")
        .sheet(isPresented: $showingUpdateCheck) { UpdateCheckView(language: preferences.language) }
        .confirmationDialog("Permanently erase every ledger entry? Categories, settings and exports will be kept.", isPresented: $showingEraseConfirmation, titleVisibility: .visible) {
            Button("Erase All Entries", role: .destructive) {
                Task {
                    do {
                        try await repository.deleteAllEntries()
                        try storage.removeManagedMigrationStaging()
                        eraseMessage = nil
                    } catch { eraseMessage = error.localizedDescription }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func chooseLocation() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let parent = panel.url else { return }
        do { try storage.schedule(parent: parent); storageMessage = nil } catch { storageMessage = error.localizedDescription }
    }
}

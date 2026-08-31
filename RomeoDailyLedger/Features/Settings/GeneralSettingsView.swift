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
                TextField(AppLocalization.text("settings.general.customCurrency", language: preferences.language), text: $preferences.currencyCode).frame(maxWidth: 180).accessibilityIdentifier("settings-currency")
                Picker(AppLocalization.text("settings.general.language", language: preferences.language), selection: $preferences.language) {
                    Text(AppLocalization.text("language.zhHans", language: preferences.language)).tag(AppLanguage.simplifiedChinese)
                    Text(AppLocalization.text("language.en", language: preferences.language)).tag(AppLanguage.english)
                }.pickerStyle(.segmented).frame(maxWidth: 300).accessibilityIdentifier("settings-language")
            }
            Section(AppLocalization.text("settings.storage.title", language: preferences.language)) {
                Text(storage.activeDirectory.path).textSelection(.enabled)
                if storage.pendingDirectory != nil { Text(AppLocalization.text("settings.storage.pending", language: preferences.language)).foregroundStyle(.secondary) }
                HStack {
                    Button(AppLocalization.text("settings.storage.change", language: preferences.language), action: chooseLocation)
                    Button(AppLocalization.text("settings.storage.showFinder", language: preferences.language)) { NSWorkspace.shared.activateFileViewerSelecting([storage.activeDirectory]) }
                    Button(AppLocalization.text("settings.storage.restore", language: preferences.language)) { storage.restoreDefaultOnNextLaunch() }
                }
                if let storageMessage { Text(storageMessage).foregroundStyle(.red) }
            }
            Section {
                Button(AppLocalization.text("settings.storage.erase", language: preferences.language), role: .destructive) { showingEraseConfirmation = true }
                if let eraseMessage { Text(eraseMessage).foregroundStyle(.red) }
            }
            Section(AppLocalization.text("settings.update.section", language: preferences.language)) {
                Button(AppLocalization.text("settings.update.check", language: preferences.language)) { showingUpdateCheck = true }
            }
        }
        .formStyle(.grouped).navigationTitle(AppLocalization.text("settings.general.title", language: preferences.language)).padding(24)
        .accessibilityIdentifier("settings-general")
        .sheet(isPresented: $showingUpdateCheck) { UpdateCheckView(language: preferences.language) }
        .confirmationDialog(AppLocalization.text("settings.storage.eraseConfirm", language: preferences.language), isPresented: $showingEraseConfirmation, titleVisibility: .visible) {
            Button(AppLocalization.text("settings.storage.erase", language: preferences.language), role: .destructive) {
                Task {
                    do {
                        try await repository.deleteAllEntries()
                        try storage.removeManagedMigrationStaging()
                        eraseMessage = nil
                    } catch { eraseMessage = error.localizedDescription }
                }
            }
            Button(AppLocalization.text("button.cancel", language: preferences.language), role: .cancel) {}
        }
    }

    private func chooseLocation() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let parent = panel.url else { return }
        do { try storage.schedule(parent: parent); storageMessage = nil } catch { storageMessage = error.localizedDescription }
    }
}

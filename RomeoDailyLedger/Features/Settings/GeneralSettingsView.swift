import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var preferences: AppPreferences
    let storage: StorageCoordinator
    @State private var showingUpdateCheck = false
    @State private var storageMessage: String?

    var body: some View {
        SettingsPageScroll {
            SettingsPageSection(AppLocalization.text("settings.general.regional", language: preferences.language)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Text(AppLocalization.text("settings.general.currency", language: preferences.language))
                            .frame(width: 110, alignment: .leading)
                        CurrencyInputField(preferences: preferences)
                        Spacer(minLength: 0)
                    }
                    Divider()
                    HStack(spacing: 12) {
                        Text(AppLocalization.text("settings.general.language", language: preferences.language))
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $preferences.language) {
                            Text(AppLocalization.text("language.zhHans", language: preferences.language)).tag(AppLanguage.simplifiedChinese)
                            Text(AppLocalization.text("language.zhHant", language: preferences.language)).tag(AppLanguage.traditionalChinese)
                            Text(AppLocalization.text("language.en", language: preferences.language)).tag(AppLanguage.english)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(AppLocalization.text("settings.general.language", language: preferences.language))
                        .accessibilityIdentifier("settings-language")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            SettingsPageSection(AppLocalization.text("settings.storage.title", language: preferences.language)) {
                Text(storage.activeDirectory.path).textSelection(.enabled)
                if storage.pendingDirectory != nil { Text(AppLocalization.text("settings.storage.pending", language: preferences.language)).foregroundStyle(.secondary) }
                HStack {
                    Button(AppLocalization.text("settings.storage.change", language: preferences.language), action: chooseLocation)
                    Button(AppLocalization.text("settings.storage.showFinder", language: preferences.language)) { NSWorkspace.shared.activateFileViewerSelecting([storage.activeDirectory]) }
                    Button(AppLocalization.text("settings.storage.restore", language: preferences.language)) { storage.restoreDefaultOnNextLaunch() }
                }
                .controlSize(.small)
                if let storageMessage { Text(storageMessage).foregroundStyle(.red) }
            }
            SettingsPageSection(AppLocalization.text("settings.update.section", language: preferences.language)) {
                Button(AppLocalization.text("settings.update.check", language: preferences.language)) { showingUpdateCheck = true }
                    .accessibilityIdentifier("settings-check-for-updates")
            }
        }
        .padding(SettingsPageLayout.contentInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(AppLocalization.text("settings.general.title", language: preferences.language))
        .accessibilityIdentifier("settings-general")
        .sheet(isPresented: $showingUpdateCheck) { UpdateCheckView(language: preferences.language) }
    }

    private func chooseLocation() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let parent = panel.url else { return }
        do { try storage.schedule(parent: parent); storageMessage = nil } catch { storageMessage = error.localizedDescription }
    }
}

private struct CurrencyInputField: View {
    @Bindable var preferences: AppPreferences
    @State private var draft = ""
    private let commonCurrencies = ["CNY", "USD", "EUR", "GBP", "JPY", "HKD"]

    var body: some View {
        HStack(spacing: 4) {
            TextField(AppLocalization.text("settings.general.currency", language: preferences.language), text: $draft)
                .textFieldStyle(.plain)
                .onSubmit(acceptDraft)
                .accessibilityIdentifier("settings-currency")
            Menu {
                ForEach(commonCurrencies, id: \.self) { currency in
                    Button(currency) { select(currency) }
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .accessibilityLabel(AppLocalization.text("settings.general.currency", language: preferences.language))
            .accessibilityIdentifier("settings-currency-options")
        }
        .padding(.horizontal, 7)
        .frame(width: 180, height: 24)
        .background(.background, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.quaternary))
        .onAppear { draft = preferences.currencyCode }
        .onChange(of: preferences.currencyCode) { _, value in draft = value }
    }

    private func acceptDraft() {
        preferences.currencyCode = draft
        draft = preferences.currencyCode
    }

    private func select(_ currency: String) {
        draft = currency
        acceptDraft()
    }
}

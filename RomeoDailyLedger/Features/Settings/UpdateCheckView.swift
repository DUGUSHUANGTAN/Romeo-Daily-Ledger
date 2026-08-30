import SwiftUI

struct UpdateCheckView: View {
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var result: ReleaseUpdateResult?
    @State private var error: ReleaseUpdateError?
    @State private var isChecking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(text("settings.update.title")).font(.title2.bold())
            LabeledContent(text("settings.update.current"), value: ReleaseUpdateService.currentVersion)
            resultView
            if let error { Text(text(errorKey(error))).foregroundStyle(.red) }
            HStack {
                Button(isChecking ? text("settings.update.checking") : text("settings.update.check")) { check() }
                    .disabled(isChecking)
                Link(text("settings.update.releasePage"), destination: ReleaseUpdateService.releasesPage)
                Spacer()
                Button(text("button.close")) { dismiss() }
            }
        }
        .padding(24)
        .frame(width: 460)
        .task { check() }
    }

    @ViewBuilder private var resultView: some View {
        if let result {
            switch result {
            case .updateAvailable(let release):
                LabeledContent(text("settings.update.latest"), value: release.tagName)
                Text(text("settings.update.available"))
                Link(text("settings.update.openRelease"), destination: release.htmlURL)
            case .upToDate(let release):
                LabeledContent(text("settings.update.latest"), value: release.tagName)
                Text(text("settings.update.upToDate"))
            }
        }
    }

    private func check() {
        isChecking = true
        result = nil
        error = nil
        Task {
            defer { isChecking = false }
            do { result = try await ReleaseUpdateService.check() }
            catch let updateError as ReleaseUpdateError { error = updateError }
            catch { self.error = .network }
        }
    }

    private func text(_ key: String) -> String { AppLocalization.text(key, language: language) }
    private func errorKey(_ error: ReleaseUpdateError) -> String {
        switch error {
        case .noRelease: "settings.update.error.noRelease"
        case .repositoryNotFound: "settings.update.error.notFound"
        case .rateLimited: "settings.update.error.rateLimited"
        case .invalidResponse: "settings.update.error.invalidResponse"
        case .network: "settings.update.error.network"
        }
    }
}

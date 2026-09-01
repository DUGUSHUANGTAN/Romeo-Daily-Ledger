import Foundation
import Observation
import SwiftData

struct AppLaunchState {
    let recoveryMessage: String?

    init(storageError: Error? = nil) {
        recoveryMessage = storageError?.localizedDescription
    }

    var canOpenLedger: Bool { recoveryMessage == nil }
}

@MainActor @Observable
final class AppDependencies {
    var selectedDestination: SidebarDestination
    let preferences: AppPreferences
    let modelContainer: ModelContainer
    let repository: LedgerRepository
    let deletionUndoCoordinator: DeletionUndoCoordinator
    let aiClient: any AIRequesting
    let storage: StorageCoordinator
    let launchState: AppLaunchState

    init(
        selectedDestination: SidebarDestination = .ledger,
        preferences: AppPreferences? = nil,
        aiClient: (any AIRequesting)? = nil
    ) {
        let usesInMemoryStore = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let storage = StorageCoordinator()
        var launchError: Error?
        let container: ModelContainer
        do {
            if !usesInMemoryStore { try storage.prepareBeforeOpeningContainer() }
            container = try usesInMemoryStore
                ? ModelContainerFactory.inMemory()
                : ModelContainerFactory.persistent(storeURL: StorageLayout(directory: storage.activeDirectory).storeURL)
        } catch {
            launchError = error
            // The temporary container only satisfies dependency construction. RootView
            // gates all ledger access while recovery is required.
            container = try! ModelContainerFactory.inMemory()
        }
        let repository = SwiftDataLedgerRepository(context: container.mainContext)
        let resolvedPreferences: AppPreferences
        if let preferences {
            resolvedPreferences = preferences
        } else if usesInMemoryStore {
            let suiteName = "RomeoDailyLedger.UITesting.\(UUID().uuidString)"
            let settingsDirectory = FileManager.default.temporaryDirectory
                .appending(path: "RomeoDailyLedger-UITesting-\(UUID().uuidString)", directoryHint: .isDirectory)
            resolvedPreferences = AppPreferences(
                defaults: UserDefaults(suiteName: suiteName)!,
                settingsStore: SettingsStore(directory: settingsDirectory)
            )
        } else {
            resolvedPreferences = AppPreferences()
        }
        if ProcessInfo.processInfo.arguments.contains("--language-en") {
            resolvedPreferences.language = .english
        } else if ProcessInfo.processInfo.arguments.contains("--language-zh-Hant") {
            resolvedPreferences.language = .traditionalChinese
        } else if ProcessInfo.processInfo.arguments.contains("--language-zh-Hans") {
            resolvedPreferences.language = .simplifiedChinese
        }
        self.selectedDestination = selectedDestination
        self.preferences = resolvedPreferences
        self.modelContainer = container
        self.repository = repository
        self.storage = storage
        self.launchState = AppLaunchState(storageError: launchError)
        self.deletionUndoCoordinator = DeletionUndoCoordinator(repository: repository)
        self.aiClient = aiClient ?? (usesInMemoryStore ? UITestingAIClient() : AIClient())
    }
}

private struct UITestingAIClient: AIRequesting {
    func parseLedger(
        text: String,
        currencyCode: String,
        configuration: AIConfiguration
    ) async throws -> AILedgerDraftEnvelope {
        AILedgerDraftEnvelope(entries: [
            AILedgerDraft(
                kind: .expense,
                amount: 25,
                currency: currencyCode,
                date: .now,
                note: "UI Test Lunch",
                category: "food"
            )
        ])
    }

    func testConnection(configuration: AIConfiguration) async throws {}

    func analyze(
        question: String,
        scope: AIAnalysisScope,
        configuration: AIConfiguration
    ) async throws -> String {
        "UI test analysis"
    }
}

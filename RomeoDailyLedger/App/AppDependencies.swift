import Foundation
import Observation
import SwiftData

@MainActor @Observable
final class AppDependencies {
    var selectedDestination: SidebarDestination
    let preferences: AppPreferences
    let modelContainer: ModelContainer
    let repository: LedgerRepository
    let deletionUndoCoordinator: DeletionUndoCoordinator

    init(selectedDestination: SidebarDestination = .ledger, preferences: AppPreferences? = nil) {
        let usesInMemoryStore = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let container = try! (usesInMemoryStore ? ModelContainerFactory.inMemory() : ModelContainerFactory.persistent())
        let repository = SwiftDataLedgerRepository(context: container.mainContext)
        let resolvedPreferences: AppPreferences
        if let preferences {
            resolvedPreferences = preferences
        } else if usesInMemoryStore {
            let suiteName = "RomeoDailyLedger.UITesting.\(UUID().uuidString)"
            resolvedPreferences = AppPreferences(defaults: UserDefaults(suiteName: suiteName)!)
        } else {
            resolvedPreferences = AppPreferences()
        }
        if ProcessInfo.processInfo.arguments.contains("--language-en") {
            resolvedPreferences.language = .english
        } else if ProcessInfo.processInfo.arguments.contains("--language-zh-Hans") {
            resolvedPreferences.language = .simplifiedChinese
        }
        self.selectedDestination = selectedDestination
        self.preferences = resolvedPreferences
        self.modelContainer = container
        self.repository = repository
        self.deletionUndoCoordinator = DeletionUndoCoordinator(repository: repository)
    }
}

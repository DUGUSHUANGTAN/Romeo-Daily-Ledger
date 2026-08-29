import Foundation
import Observation
import SwiftData

@MainActor @Observable
final class AppDependencies {
    var selectedDestination: SidebarDestination
    var themeMode: ThemeMode
    var typographyStyle: AppTypography.Style
    var motionIntensity: Int
    let modelContainer: ModelContainer
    let repository: LedgerRepository
    let deletionUndoCoordinator: DeletionUndoCoordinator

    init(selectedDestination: SidebarDestination = .ledger, themeMode: ThemeMode = .system, typographyStyle: AppTypography.Style = .system, motionIntensity: Int = 50) {
        let usesInMemoryStore = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let container = try! (usesInMemoryStore ? ModelContainerFactory.inMemory() : ModelContainerFactory.persistent())
        let repository = SwiftDataLedgerRepository(context: container.mainContext)
        self.selectedDestination = selectedDestination
        self.themeMode = themeMode
        self.typographyStyle = typographyStyle
        self.motionIntensity = min(max(motionIntensity, 0), 100)
        self.modelContainer = container
        self.repository = repository
        self.deletionUndoCoordinator = DeletionUndoCoordinator(repository: repository)
    }
}

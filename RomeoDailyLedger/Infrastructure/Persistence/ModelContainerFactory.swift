import SwiftData

enum ModelContainerFactory {
    static func inMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: LedgerEntry.self,
            Category.self,
            configurations: configuration
        )
    }
}

import SwiftData

enum ModelContainerFactory {
    static func persistent() throws -> ModelContainer {
        try ModelContainer(for: LedgerEntry.self, Category.self)
    }

    static func inMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: LedgerEntry.self,
            Category.self,
            configurations: configuration
        )
    }
}

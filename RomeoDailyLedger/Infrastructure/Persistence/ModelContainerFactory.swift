import Foundation
import SwiftData

enum ModelContainerFactory {
    static func persistent(storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: LedgerEntry.self, Category.self, configurations: configuration)
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

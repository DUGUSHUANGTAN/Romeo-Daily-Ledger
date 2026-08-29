import SwiftData
@testable import RomeoDailyLedger

@MainActor
enum TestRepository {
    static func make() throws -> SwiftDataLedgerRepository {
        let container = try ModelContainerFactory.inMemory()
        return SwiftDataLedgerRepository(context: ModelContext(container))
    }
}

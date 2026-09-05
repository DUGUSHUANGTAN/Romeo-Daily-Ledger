import XCTest
@testable import RomeoDailyLedger

final class StorageTests: XCTestCase {
    func testDefaultLocationAndManagedFiles() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let layout = StorageLayout(applicationSupport: root)
        XCTAssertEqual(layout.activeDirectory.lastPathComponent, "com.romeoke.RomeoDailyLedger")
        XCTAssertEqual(layout.storeURL.lastPathComponent, "default.store")
        XCTAssertEqual(layout.settingsURL.lastPathComponent, "settings.json")
        XCTAssertEqual(layout.formatVersionURL.lastPathComponent, "format-version.json")
        XCTAssertEqual(Set(layout.databaseFiles.map(\.lastPathComponent)), ["default.store", "default.store-wal", "default.store-shm"])
    }

    @MainActor func testPreferencesRoundTripThroughSettingsFileNotDefaults() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defer { defaults.removePersistentDomain(forName: defaults.volatileDomainNames.first ?? "") }
        let store = SettingsStore(directory: directory)
        let keychain = FakeKeychain(value: nil)
        let preferences = AppPreferences(defaults: defaults, settingsStore: store, keychain: keychain)
        preferences.currencyCode = "eur"
        preferences.language = .english
        preferences.apiKey = "TEST-KEY-NOT-REAL"
        let loaded = AppPreferences(defaults: defaults, settingsStore: store, keychain: keychain)
        XCTAssertEqual(loaded.currencyCode, "EUR")
        XCTAssertEqual(loaded.apiKey, "TEST-KEY-NOT-REAL")
        XCTAssertNil(defaults.string(forKey: "preferences.currencyCode"))
    }

    func testLocationValidatorRejectsCloudBundleNetworkAndReadOnly() throws {
        let validator = StorageLocationValidator()
        XCTAssertThrowsError(try validator.validate(parent: URL(fileURLWithPath: "/Applications/Fake.app/Contents")))
        XCTAssertThrowsError(try validator.validate(parent: URL(fileURLWithPath: "/Volumes/Remote"), volumeValues: [.volumeIsLocalKey: false]))
        XCTAssertThrowsError(try validator.validate(parent: URL(fileURLWithPath: "/tmp/iCloud Drive")))
        XCTAssertThrowsError(try validator.validate(parent: URL(fileURLWithPath: "/tmp/cloud"), volumeValues: [.isUbiquitousItemKey: true]))
        XCTAssertThrowsError(try validator.validate(parent: URL(fileURLWithPath: "/tmp/readonly"), isWritable: false))
        XCTAssertThrowsError(try validator.validate(parent: Bundle.main.bundleURL))
    }

    func testMigrationCopiesDatabaseFamilyAndIsRepeatable() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let source = base.appending(path: "source")
        let target = base.appending(path: "target")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        for name in ["default.store", "default.store-wal", "default.store-shm"] {
            try Data(name.utf8).write(to: source.appending(path: name))
        }
        let migrator = StorageMigrator()
        try migrator.copyDatabaseFamily(from: source, to: target)
        try migrator.copyDatabaseFamily(from: source, to: target)
        XCTAssertEqual(try Data(contentsOf: target.appending(path: "default.store")), Data("default.store".utf8))
        XCTAssertEqual(try Data(contentsOf: target.appending(path: "default.store-wal")), Data("default.store-wal".utf8))
        XCTAssertEqual(try Data(contentsOf: target.appending(path: "default.store-shm")), Data("default.store-shm".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.appending(path: ".(name).migration").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.appending(path: "migration-state.json").path))
    }

    func testSuccessfulMigrationDeletesOnlyManagedSourceDatabaseAndCompletes() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let source = base.appending(path: "source"), target = base.appending(path: "target")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        for name in ["default.store", "default.store-wal", "default.store-shm"] { try Data(name.utf8).write(to: source.appending(path: name)) }
        try Data("keep".utf8).write(to: source.appending(path: "user-export.csv"))
        try StorageMigrator().migrate(from: source, to: target) {}
        XCTAssertTrue(StorageLayout(directory: source).databaseFiles.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.appending(path: "user-export.csv").path))
        let state = try JSONDecoder().decode(MigrationState.self, from: Data(contentsOf: target.appending(path: "migration-state.json")))
        XCTAssertEqual(state.status, .complete)
    }

    func testFailedVerificationPreservesSourceAndRecordsRecovery() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let source = base.appending(path: "source"), target = base.appending(path: "target")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data("db".utf8).write(to: source.appending(path: "default.store"))
        XCTAssertThrowsError(try StorageMigrator().migrate(from: source, to: target) { throw CocoaError(.fileReadCorruptFile) })
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.appending(path: "default.store").path))
        let state = try JSONDecoder().decode(MigrationState.self, from: Data(contentsOf: target.appending(path: "migration-state.json")))
        XCTAssertEqual(state.status, .recoveryRequired)
    }

    func testCustomMigrationRemovesOldManagedDirectoryAfterVerification() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let source = base.appending(path: "old"), target = base.appending(path: "new")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data("db".utf8).write(to: source.appending(path: "default.store"))
        try Data("{}".utf8).write(to: source.appending(path: "settings.json"))
        try StorageMigrator().migrate(from: source, to: target, removeSourceDirectory: true) {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
    }

    func testMigrationCanPreserveSourceUntilLocationCommit() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let source = base.appending(path: "old"), target = base.appending(path: "new")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data("db".utf8).write(to: source.appending(path: "default.store"))

        try StorageMigrator().migrate(from: source, to: target, preserveSource: true) {}

        XCTAssertTrue(FileManager.default.fileExists(atPath: source.appending(path: "default.store").path))
        let state = try JSONDecoder().decode(MigrationState.self, from: Data(contentsOf: target.appending(path: "migration-state.json")))
        XCTAssertEqual(state.status, .complete)
    }

    func testCorruptSettingsFailsDecoding() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: directory.appending(path: "settings.json"))
        XCTAssertThrowsError(try SettingsStore(directory: directory).load())
    }

    @MainActor func testScheduledLocationUsesBookmarkData() throws {
        let support = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let coordinator = StorageCoordinator(defaults: defaults, applicationSupport: support, keychain: FakeKeychain(value: nil))
        try coordinator.schedule(parent: support)
        XCTAssertNotNil(defaults.data(forKey: StorageCoordinator.pendingDirectoryKey))
        XCTAssertEqual(coordinator.pendingDirectory?.lastPathComponent, "Romeo Daily Ledger Data")
    }

    @MainActor func testLegacyKeyMovesToActiveKeychainAccountWithoutEnteringJSON() throws {
        let support = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let keychain = FakeKeychain(value: "TEST-MIGRATION-KEY-NOT-REAL")
        let coordinator = StorageCoordinator(defaults: defaults, applicationSupport: support, keychain: keychain)
        try coordinator.prepareBeforeOpeningContainer()
        let settings = try XCTUnwrap(SettingsStore(directory: coordinator.activeDirectory).load())
        XCTAssertTrue(settings.aiConfiguration.apiKey.isEmpty)
        XCTAssertEqual(keychain.values["active"], "TEST-MIGRATION-KEY-NOT-REAL")
        XCTAssertTrue(keychain.wasDeleted)
    }
}

private final class FakeKeychain: AIKeychainStoring, @unchecked Sendable {
    var values: [String: String] = [:]
    var wasDeleted = false
    init(value: String?) { values["apiKey"] = value }
    func read(service: String, account: String) throws -> String? { values[account] }
    func save(_ value: String, service: String, account: String) throws { values[account] = value }
    func delete(service: String, account: String) throws { wasDeleted = true; values[account] = nil }
}

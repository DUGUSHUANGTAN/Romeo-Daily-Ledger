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
        let preferences = AppPreferences(defaults: defaults, settingsStore: store)
        preferences.currencyCode = "eur"
        preferences.language = .english
        preferences.apiKey = "TEST-KEY-NOT-REAL"
        let loaded = AppPreferences(defaults: defaults, settingsStore: store)
        XCTAssertEqual(loaded.currencyCode, "EUR")
        XCTAssertEqual(loaded.apiKey, "TEST-KEY-NOT-REAL")
        XCTAssertNil(defaults.string(forKey: "preferences.currencyCode"))
    }

    func testLocationValidatorRejectsCloudBundleNetworkAndReadOnly() throws {
        let validator = StorageLocationValidator()
        XCTAssertThrowsError(try validator.validate(parent: URL(fileURLWithPath: "/Applications/Fake.app/Contents")))
        XCTAssertThrowsError(try validator.validate(parent: URL(fileURLWithPath: "/Volumes/Remote"), volumeValues: [.volumeIsLocalKey: false]))
        XCTAssertThrowsError(try validator.validate(parent: URL(fileURLWithPath: "/tmp/iCloud Drive")))
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
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.appending(path: "migration-state.json").path))
    }

    @MainActor func testLegacyKeyIsPersistedThenDeleted() throws {
        let support = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let keychain = FakeKeychain(value: "TEST-MIGRATION-KEY-NOT-REAL")
        let coordinator = StorageCoordinator(defaults: defaults, applicationSupport: support, keychain: keychain)
        try coordinator.prepareBeforeOpeningContainer()
        let settings = try XCTUnwrap(SettingsStore(directory: coordinator.activeDirectory).load())
        XCTAssertEqual(settings.aiConfiguration.apiKey, "TEST-MIGRATION-KEY-NOT-REAL")
        XCTAssertTrue(keychain.wasDeleted)
    }
}

private final class FakeKeychain: AIKeychainStoring, @unchecked Sendable {
    var value: String?
    var wasDeleted = false
    init(value: String?) { self.value = value }
    func read(service: String, account: String) throws -> String? { value }
    func save(_ value: String, service: String, account: String) throws { self.value = value }
    func delete(service: String, account: String) throws { wasDeleted = true; value = nil }
}

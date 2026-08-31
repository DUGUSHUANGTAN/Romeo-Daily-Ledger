import Foundation
import SwiftData

struct StorageLayout: Sendable {
    static let directoryName = "com.romeoke.RomeoDailyLedger"
    let activeDirectory: URL

    init(applicationSupport: URL) {
        activeDirectory = applicationSupport.appending(path: Self.directoryName, directoryHint: .isDirectory)
    }

    init(directory: URL, isExactDirectory: Bool = true) { activeDirectory = directory }
    var storeURL: URL { activeDirectory.appending(path: "default.store") }
    var settingsURL: URL { activeDirectory.appending(path: "settings.json") }
    var formatVersionURL: URL { activeDirectory.appending(path: "format-version.json") }
    var migrationStateURL: URL { activeDirectory.appending(path: "migration-state.json") }
    var databaseFiles: [URL] { [storeURL, URL(fileURLWithPath: storeURL.path + "-wal"), URL(fileURLWithPath: storeURL.path + "-shm")] }
}

struct StoredSettings: Codable, Equatable, Sendable {
    var currencyCode = "USD"
    var language = AppLanguage.simplifiedChinese.rawValue
    var themeMode = ThemeMode.system.rawValue
    var typographyStyle = AppTypography.Style.system.rawValue
    var motionIntensity = 50
    var aiConfiguration = AIConfiguration()
}

struct SettingsStore: Sendable {
    let directory: URL
    var url: URL { directory.appending(path: "settings.json") }
    func load() throws -> StoredSettings? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(StoredSettings.self, from: Data(contentsOf: url))
    }
    func save(_ settings: StoredSettings) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.pretty.encode(settings)
        try data.write(to: url, options: .atomic)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return encoder }
}

enum StorageLocationError: LocalizedError, Equatable {
    case applicationBundle, cloudSynchronized, networkVolume, notWritable
    var errorDescription: String? {
        switch self {
        case .applicationBundle: "Cannot store data inside an application bundle."
        case .cloudSynchronized: "Cloud-synchronized folders are not supported."
        case .networkVolume: "Network volumes are not supported."
        case .notWritable: "The selected folder is not writable."
        }
    }
}

struct StorageLocationValidator {
    func validate(parent: URL, volumeValues: [URLResourceKey: Bool]? = nil) throws {
        let path = parent.standardizedFileURL.path.lowercased()
        if path.contains(".app/contents") { throw StorageLocationError.applicationBundle }
        if ["icloud", "mobile documents", "dropbox", "onedrive", "google drive"].contains(where: path.contains) {
            throw StorageLocationError.cloudSynchronized
        }
        let local = volumeValues?[.volumeIsLocalKey] ?? ((try? parent.resourceValues(forKeys: [.volumeIsLocalKey]).volumeIsLocal) ?? true)
        if !local { throw StorageLocationError.networkVolume }
        if FileManager.default.fileExists(atPath: parent.path), !FileManager.default.isWritableFile(atPath: parent.path) {
            throw StorageLocationError.notWritable
        }
    }
}

struct MigrationState: Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case pending, copying, verified, complete, recoveryRequired }
    var status: Status
    var source: String
    var target: String
    var message: String?
}

struct StorageMigrator: Sendable {
    func copyDatabaseFamily(from source: URL, to target: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: target, withIntermediateDirectories: true)
        try writeState(.init(status: .copying, source: source.path, target: target.path), to: target)
        for name in ["default.store", "default.store-wal", "default.store-shm"] {
            let from = source.appending(path: name), to = target.appending(path: name)
            guard fm.fileExists(atPath: from.path) else { continue }
            let temporary = target.appending(path: ".(name).migration")
            try? fm.removeItem(at: temporary)
            try fm.copyItem(at: from, to: temporary)
            try? fm.removeItem(at: to)
            try fm.moveItem(at: temporary, to: to)
        }
        for name in ["settings.json", "format-version.json"] where fm.fileExists(atPath: source.appending(path: name).path) {
            let destination = target.appending(path: name)
            try? fm.removeItem(at: destination)
            try fm.copyItem(at: source.appending(path: name), to: destination)
        }
        guard fm.fileExists(atPath: target.appending(path: "default.store").path) else { throw CocoaError(.fileNoSuchFile) }
        try writeState(.init(status: .complete, source: source.path, target: target.path), to: target)
    }

    func writeState(_ state: MigrationState, to directory: URL) throws {
        try JSONEncoder.pretty.encode(state).write(to: directory.appending(path: "migration-state.json"), options: .atomic)
    }
}

@MainActor final class StorageCoordinator {
    static let activeDirectoryKey = "storage.activeDirectory"
    static let pendingDirectoryKey = "storage.pendingDirectory"
    let defaults: UserDefaults
    let defaultDirectory: URL
    private let migrator = StorageMigrator()
    private let keychain: any AIKeychainStoring

    init(defaults: UserDefaults = .standard, applicationSupport: URL? = nil, keychain: any AIKeychainStoring = KeychainAIKeyStore()) {
        self.defaults = defaults
        self.keychain = keychain
        let support = applicationSupport ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        defaultDirectory = StorageLayout(applicationSupport: support).activeDirectory
    }
    var activeDirectory: URL { defaults.string(forKey: Self.activeDirectoryKey).map(URL.init(fileURLWithPath:)) ?? defaultDirectory }
    var pendingDirectory: URL? { defaults.string(forKey: Self.pendingDirectoryKey).map(URL.init(fileURLWithPath:)) }
    func schedule(parent: URL) throws {
        try StorageLocationValidator().validate(parent: parent)
        defaults.set(parent.appending(path: "Romeo Daily Ledger Data", directoryHint: .isDirectory).path, forKey: Self.pendingDirectoryKey)
    }
    func restoreDefaultOnNextLaunch() { defaults.set(defaultDirectory.path, forKey: Self.pendingDirectoryKey) }
    func prepareBeforeOpeningContainer() throws {
        let target = pendingDirectory ?? activeDirectory
        try migrateLegacyStoreIfNeeded(to: target)
        if let pendingDirectory, pendingDirectory != activeDirectory, FileManager.default.fileExists(atPath: activeDirectory.appending(path: "default.store").path) {
            do {
                let expected = try databaseCounts(at: activeDirectory)
                try migrator.copyDatabaseFamily(from: activeDirectory, to: pendingDirectory)
                guard try databaseCounts(at: pendingDirectory) == expected else { throw CocoaError(.fileReadCorruptFile) }
                _ = try SettingsStore(directory: pendingDirectory).load()
                defaults.set(pendingDirectory.path, forKey: Self.activeDirectoryKey); defaults.removeObject(forKey: Self.pendingDirectoryKey)
            }
            catch { try? migrator.writeState(.init(status: .recoveryRequired, source: activeDirectory.path, target: pendingDirectory.path, message: error.localizedDescription), to: pendingDirectory); throw error }
        }
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: StorageLayout(directory: target).formatVersionURL.path) {
            try Data("{\"version\":1}".utf8).write(to: StorageLayout(directory: target).formatVersionURL, options: .atomic)
        }
        try migrateLegacyPreferencesAndKeyIfNeeded(in: target)
    }

    private func migrateLegacyStoreIfNeeded(to target: URL) throws {
        let destination = target.appending(path: "default.store")
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        let legacy = defaultDirectory.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: legacy.appending(path: "default.store").path) else { return }
        try migrator.copyDatabaseFamily(from: legacy, to: target)
        guard try databaseCounts(at: legacy) == databaseCounts(at: target) else { throw CocoaError(.fileReadCorruptFile) }
    }

    private func migrateLegacyPreferencesAndKeyIfNeeded(in directory: URL) throws {
        let store = SettingsStore(directory: directory)
        if try store.load() != nil { return }
        var settings = StoredSettings()
        settings.currencyCode = defaults.string(forKey: "preferences.currencyCode") ?? settings.currencyCode
        settings.language = defaults.string(forKey: "preferences.language") ?? settings.language
        settings.themeMode = defaults.string(forKey: "preferences.themeMode") ?? settings.themeMode
        settings.motionIntensity = defaults.object(forKey: "preferences.motionIntensity") == nil ? settings.motionIntensity : defaults.integer(forKey: "preferences.motionIntensity")
        if let data = defaults.data(forKey: "preferences.aiConfiguration"), let configuration = try? JSONDecoder().decode(AIConfiguration.self, from: data) { settings.aiConfiguration = configuration }
        if let key = try keychain.read(service: KeychainAIKeyStore.service, account: "apiKey") { settings.aiConfiguration.apiKey = key }
        try store.save(settings)
        guard try store.load() == settings else { throw CocoaError(.fileWriteUnknown) }
        if !settings.aiConfiguration.apiKey.isEmpty { try keychain.delete(service: KeychainAIKeyStore.service, account: "apiKey") }
    }

    private func databaseCounts(at directory: URL) throws -> (Int, Int) {
        let container = try ModelContainerFactory.persistent(storeURL: directory.appending(path: "default.store"))
        return (try container.mainContext.fetchCount(FetchDescriptor<LedgerEntry>()), try container.mainContext.fetchCount(FetchDescriptor<Category>()))
    }
}

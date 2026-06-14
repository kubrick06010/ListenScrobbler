import Foundation

struct CompatibilityStoredAccounts: Codable, Equatable {
    var activeUsername: String?
    var sessions: [CompatibilitySession]
}

protocol CompatibilityAccountsStoring {
    func save(_ session: CompatibilitySession)
    func load() -> CompatibilitySession?
    func clear()
    func allSessions() -> [CompatibilitySession]
    func setActive(username: String?)
    func remove(username: String)
}

final class CompatibilitySessionStore: CompatibilityAccountsStoring {
    private let fileManager: FileManager
    private let storageFileURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ListenScrobbler", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.storageFileURL = dir.appendingPathComponent("accounts.json")
    }

    func save(_ session: CompatibilitySession) {
        var storage = loadStorage()
        storage.sessions.removeAll { $0.name.caseInsensitiveCompare(session.name) == .orderedSame }
        storage.sessions.append(session)
        storage.sessions.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        storage.activeUsername = session.name
        persist(storage)
    }

    func load() -> CompatibilitySession? {
        let storage = loadStorage()
        guard let activeUsername = storage.activeUsername else {
            return storage.sessions.first
        }
        return storage.sessions.first { $0.name.caseInsensitiveCompare(activeUsername) == .orderedSame }
    }

    func clear() {
        var storage = loadStorage()
        guard let activeUsername = storage.activeUsername else {
            return
        }
        storage.sessions.removeAll { $0.name.caseInsensitiveCompare(activeUsername) == .orderedSame }
        storage.activeUsername = storage.sessions.first?.name
        persist(storage)
    }

    func allSessions() -> [CompatibilitySession] {
        loadStorage().sessions
    }

    func setActive(username: String?) {
        var storage = loadStorage()
        guard let username else {
            storage.activeUsername = nil
            persist(storage)
            return
        }
        guard storage.sessions.contains(where: { $0.name.caseInsensitiveCompare(username) == .orderedSame }) else {
            return
        }
        storage.activeUsername = username
        persist(storage)
    }

    func remove(username: String) {
        var storage = loadStorage()
        storage.sessions.removeAll { $0.name.caseInsensitiveCompare(username) == .orderedSame }
        if storage.activeUsername?.caseInsensitiveCompare(username) == .orderedSame {
            storage.activeUsername = storage.sessions.first?.name
        }
        persist(storage)
    }

    private func loadStorage() -> CompatibilityStoredAccounts {
        guard let data = try? Data(contentsOf: storageFileURL),
              let storage = try? JSONDecoder().decode(CompatibilityStoredAccounts.self, from: data) else {
            return CompatibilityStoredAccounts(activeUsername: nil, sessions: [])
        }
        return storage
    }

    private func persist(_ storage: CompatibilityStoredAccounts) {
        guard let data = try? JSONEncoder().encode(storage) else { return }
        try? data.write(to: storageFileURL, options: .atomic)
    }
}

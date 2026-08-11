import Foundation

enum ProxyMode: String, Codable, CaseIterable, Identifiable {
    case system
    case none
    case http
    case socks5

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return AppLocalization.string("Auto Detect")
        case .none:
            return AppLocalization.string("No Proxy")
        case .http:
            return "HTTP"
        case .socks5:
            return "SOCKS5"
        }
    }
}

struct ProxySettings: Codable, Equatable {
    var mode: ProxyMode = .system
    var host: String = ""
    var port: Int? = nil
    var username: String = ""
    var password: String = ""

    static let userDefaultsKey = "network.proxySettings"

    var usesManualProxy: Bool {
        mode == .http || mode == .socks5
    }

    var hasRequiredEndpoint: Bool {
        guard usesManualProxy else { return true }
        return !normalizedHost.isEmpty && normalizedPort != nil
    }

    var normalizedHost: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedPort: Int? {
        guard let port, port > 0 else { return nil }
        return port
    }

    var normalizedUsername: String? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var normalizedPassword: String? {
        password.isEmpty ? nil : password
    }
}

protocol ProxySettingsStoring {
    func load() -> ProxySettings
    func save(_ settings: ProxySettings)
}

final class ProxySettingsStore: ProxySettingsStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ProxySettings {
        guard let data = defaults.data(forKey: ProxySettings.userDefaultsKey),
              let settings = try? JSONDecoder().decode(ProxySettings.self, from: data) else {
            return ProxySettings()
        }
        return settings
    }

    func save(_ settings: ProxySettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: ProxySettings.userDefaultsKey)
    }
}

@MainActor
final class ProxySettingsController: ObservableObject {
    @Published var settings: ProxySettings

    private let store: ProxySettingsStoring

    init(store: ProxySettingsStoring = ProxySettingsStore()) {
        self.store = store
        self.settings = store.load()
    }

    func reload() {
        settings = store.load()
    }

    func save() {
        store.save(settings)
    }

    var statusDescription: String {
        switch settings.mode {
        case .system:
            return AppLocalization.string("Using macOS system proxy settings.")
        case .none:
            return AppLocalization.string("Direct connection without a proxy.")
        case .http:
            if let port = settings.normalizedPort, !settings.normalizedHost.isEmpty {
                return AppLocalization.localizedStringWithFormat(AppLocalization.string("HTTP proxy %@:%lld"), settings.normalizedHost, Int64(port))
            }
            return AppLocalization.string("HTTP proxy needs a host and port.")
        case .socks5:
            if let port = settings.normalizedPort, !settings.normalizedHost.isEmpty {
                return AppLocalization.localizedStringWithFormat(AppLocalization.string("SOCKS5 proxy %@:%lld"), settings.normalizedHost, Int64(port))
            }
            return AppLocalization.string("SOCKS5 proxy needs a host and port.")
        }
    }
}

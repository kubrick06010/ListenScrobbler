import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var isApplyingChange = false
    @Published private(set) var statusDescription = AppLocalization.string("Not registered")
    @Published var lastErrorMessage: String?

    private let defaults = UserDefaults.standard
    private let preferenceKey = "app.launchAtLogin"

    init() {
        refreshStatus()
    }

    var storedPreference: Bool {
        defaults.bool(forKey: preferenceKey)
    }

    func refreshStatus() {
        let status = SMAppService.mainApp.status
        isEnabled = (status == .enabled)
        statusDescription = describe(status)

        // Keep a lightweight local preference so startup presentation can make
        // the same decision after relaunch without waiting for UI interaction.
        defaults.set(isEnabled, forKey: preferenceKey)
    }

    func setEnabled(_ enabled: Bool) async {
        guard enabled != isEnabled || enabled != storedPreference else { return }

        isApplyingChange = true
        lastErrorMessage = nil
        defer {
            isApplyingChange = false
            refreshStatus()
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try await SMAppService.mainApp.unregister()
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func describe(_ status: SMAppService.Status) -> String {
        switch status {
        case .enabled:
            return AppLocalization.string("Registered")
        case .notRegistered:
            return AppLocalization.string("Not registered")
        case .requiresApproval:
            return AppLocalization.string("Requires approval in Login Items")
        case .notFound:
            return AppLocalization.string("App service not found")
        @unknown default:
            return AppLocalization.string("Unknown")
        }
    }
}

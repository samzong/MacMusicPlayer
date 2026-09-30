import Foundation
import ServiceManagement

class LaunchManager {
    private let service = SMAppService.mainApp
    private let defaultsKey = "LaunchAtLogin"

    var launchAtLogin: Bool {
        get { service.status == .enabled }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsKey)
            setLaunchAtLogin(newValue)
        }
    }

    init() {
        let wanted = UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
        if wanted && service.status != .requiresApproval {
            setLaunchAtLogin(true)
        }
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        do {
            switch (enable, service.status) {
            case (true, .requiresApproval):
                SMAppService.openSystemSettingsLoginItems()
            case (true, .notRegistered), (true, .notFound):
                try service.register()
            case (false, .enabled), (false, .requiresApproval):
                try service.unregister()
            default:
                break
            }
        } catch {
            print("Failed to \(enable ? "enable" : "disable") launch at login: \(error)")
        }
    }
}

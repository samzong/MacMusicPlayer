import Foundation
import ServiceManagement
import os

class LaunchManager {
    private let logger = Logger(subsystem: "com.seimotech.MacMusicPlayer", category: "launch")
    private let service = SMAppService.mainApp
    private let defaultsKey = "LaunchAtLogin"

    var launchAtLogin: Bool {
        get { service.status == .enabled }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsKey)
            if !setLaunchAtLogin(newValue, notifyOnFailure: true) {
                UserDefaults.standard.set(service.status == .enabled, forKey: defaultsKey)
            }
        }
    }

    init() {
        let wanted = UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
        if wanted && service.status != .requiresApproval {
            _ = setLaunchAtLogin(true, notifyOnFailure: false)
        }
    }

    @discardableResult
    private func setLaunchAtLogin(_ enable: Bool, notifyOnFailure: Bool) -> Bool {
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
            return true
        } catch {
            logger.error("Failed to \(enable ? "enable" : "disable", privacy: .public) launch at login: \(error.localizedDescription, privacy: .public)")
            if notifyOnFailure {
                NotificationCenter.default.post(
                    name: NSNotification.Name("LaunchAtLoginFailed"),
                    object: nil,
                    userInfo: ["error": error.localizedDescription]
                )
            }
            return false
        }
    }
}

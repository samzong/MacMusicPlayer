import Foundation
import ServiceManagement

class LaunchManager: ObservableObject {
    private let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.seimotech.MacMusicPlayer"
    
    @Published var launchAtLogin: Bool {
        didSet {
            setLaunchAtLogin(launchAtLogin)
            UserDefaults.standard.set(launchAtLogin, forKey: "LaunchAtLogin")
        }
    }
    
    init() {
        // 从 UserDefaults 读取设置，默认为 false
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "LaunchAtLogin")
        // 确保设置与实际状态一致
        setLaunchAtLogin(launchAtLogin)
    }
    
    private func setLaunchAtLogin(_ enable: Bool) {
        if enable {
            let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, true)
            print("Enable launch at login: \(success)")
        } else {
            let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, false)
            print("Disable launch at login: \(success)")
        }
    }
} 
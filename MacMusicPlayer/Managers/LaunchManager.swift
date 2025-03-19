//
//  LaunchManager.swift
//  MacMusicPlayer
//
//  Created by X on 2024/09/18.
//

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
        self.launchAtLogin = UserDefaults.standard.object(forKey: "LaunchAtLogin") == nil ? true : UserDefaults.standard.bool(forKey: "LaunchAtLogin")
        setLaunchAtLogin(launchAtLogin)
    }
    
    private func setLaunchAtLogin(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status == .notRegistered {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("Failed to \(enable ? "enable" : "disable") launch at login: \(error)")
            }
        } else {
            _ = SMLoginItemSetEnabled(bundleIdentifier as CFString, enable)
        }
    }
} 

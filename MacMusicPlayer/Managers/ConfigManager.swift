import Foundation

class ConfigManager {
    static let shared = ConfigManager()

    private let userDefaults = UserDefaults.standard

    private enum Keys {
        static let apiKey = "ytSearchApiKey"
        static let apiUrl = "ytSearchApiUrl"
        static let showMenubarIcon = "showMenubarIcon"
    }

    private init() {}

    var apiKey: String {
        get {
            return userDefaults.string(forKey: Keys.apiKey) ?? ""
        }
        set {
            userDefaults.set(newValue, forKey: Keys.apiKey)
        }
    }

    var apiUrl: String {
        get {
            return userDefaults.string(forKey: Keys.apiUrl) ?? ""
        }
        set {
            userDefaults.set(newValue, forKey: Keys.apiUrl)
        }
    }

    var showMenubarIcon: Bool {
        get {
            return userDefaults.object(forKey: Keys.showMenubarIcon) as? Bool ?? true
        }
        set {
            userDefaults.set(newValue, forKey: Keys.showMenubarIcon)
        }
    }

    var isConfigValid: Bool {
        return !apiKey.isEmpty && !apiUrl.isEmpty
    }

    func resetConfig() {
        userDefaults.removeObject(forKey: Keys.apiKey)
        userDefaults.removeObject(forKey: Keys.apiUrl)
        userDefaults.removeObject(forKey: Keys.showMenubarIcon)
        NotificationCenter.default.post(name: NSNotification.Name("ConfigUpdated"), object: nil)
    }

    func saveConfig(apiKey: String, apiUrl: String, showMenubarIcon: Bool) {
        self.apiKey = apiKey
        self.apiUrl = apiUrl
        self.showMenubarIcon = showMenubarIcon
        NotificationCenter.default.post(name: NSNotification.Name("ConfigUpdated"), object: nil)
    }
}

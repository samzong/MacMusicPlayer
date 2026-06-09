import Foundation

class ConfigManager {
    static let shared = ConfigManager()

    private let userDefaults = UserDefaults.standard

    private enum Keys {
        static let apiKey = "ytSearchApiKey"
        static let apiUrl = "ytSearchApiUrl"
        static let showSongPickerOnLaunch = "showSongPickerOnLaunch"
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

    var showSongPickerOnLaunch: Bool {
        get {
            return userDefaults.object(forKey: Keys.showSongPickerOnLaunch) as? Bool ?? false
        }
        set {
            userDefaults.set(newValue, forKey: Keys.showSongPickerOnLaunch)
        }
    }

    var isConfigValid: Bool {
        return !apiKey.isEmpty && !apiUrl.isEmpty
    }

    func resetConfig() {
        userDefaults.removeObject(forKey: Keys.apiKey)
        userDefaults.removeObject(forKey: Keys.apiUrl)
        userDefaults.removeObject(forKey: Keys.showSongPickerOnLaunch)
    }

    func saveConfig(apiKey: String, apiUrl: String, showSongPickerOnLaunch: Bool) {
        self.apiKey = apiKey
        self.apiUrl = apiUrl
        self.showSongPickerOnLaunch = showSongPickerOnLaunch
    }
}

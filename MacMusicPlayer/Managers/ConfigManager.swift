//
//  ConfigManager.swift
//  MacMusicPlayer
//
//  Created by samzong<samzong.lu@gmail.com>
//

import Foundation

class ConfigManager {
    static let shared = ConfigManager()
    
    private let userDefaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private enum Keys {
        static let apiKey = "ytSearchApiKey"
        static let apiUrl = "ytSearchApiUrl"
        static let showSongPickerOnLaunch = "showSongPickerOnLaunch"
    }
    
    private init() {}
    
    // API Key related methods
    var apiKey: String {
        get {
            return userDefaults.string(forKey: Keys.apiKey) ?? ""
        }
        set {
            userDefaults.set(newValue, forKey: Keys.apiKey)
        }
    }
    
    // API URL related methods
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
            // Default to false if the preference has never been set
            return userDefaults.object(forKey: Keys.showSongPickerOnLaunch) as? Bool ?? false
        }
        set {
            userDefaults.set(newValue, forKey: Keys.showSongPickerOnLaunch)
        }
    }
    
    // Check if configuration is valid
    var isConfigValid: Bool {
        return !apiKey.isEmpty && !apiUrl.isEmpty
    }
    
    // Reset configuration
    func resetConfig() {
        userDefaults.removeObject(forKey: Keys.apiKey)
        userDefaults.removeObject(forKey: Keys.apiUrl)
        userDefaults.removeObject(forKey: Keys.showSongPickerOnLaunch)
    }
    
    // Save configuration
    func saveConfig(apiKey: String, apiUrl: String, showSongPickerOnLaunch: Bool) {
        self.apiKey = apiKey
        self.apiUrl = apiUrl
        self.showSongPickerOnLaunch = showSongPickerOnLaunch
    }
}

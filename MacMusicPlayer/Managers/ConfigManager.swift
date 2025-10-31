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
    
    // Check if configuration is valid
    var isConfigValid: Bool {
        return !apiKey.isEmpty && !apiUrl.isEmpty
    }
    
    // Reset configuration
    func resetConfig() {
        userDefaults.removeObject(forKey: Keys.apiKey)
        userDefaults.removeObject(forKey: Keys.apiUrl)
    }
    
    // Save configuration
    func saveConfig(apiKey: String, apiUrl: String) {
        self.apiKey = apiKey
        self.apiUrl = apiUrl
    }
} 
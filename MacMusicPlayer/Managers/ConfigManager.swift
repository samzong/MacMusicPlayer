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
    
    // API Key 相关方法
    var apiKey: String {
        get {
            return userDefaults.string(forKey: Keys.apiKey) ?? ""
        }
        set {
            userDefaults.set(newValue, forKey: Keys.apiKey)
        }
    }
    
    // API URL 相关方法
    var apiUrl: String {
        get {
            return userDefaults.string(forKey: Keys.apiUrl) ?? ""
        }
        set {
            userDefaults.set(newValue, forKey: Keys.apiUrl)
        }
    }
    
    // 判断配置是否有效
    var isConfigValid: Bool {
        return !apiKey.isEmpty && !apiUrl.isEmpty
    }
    
    // 重置配置
    func resetConfig() {
        userDefaults.removeObject(forKey: Keys.apiKey)
        userDefaults.removeObject(forKey: Keys.apiUrl)
    }
    
    // 保存配置
    func saveConfig(apiKey: String, apiUrl: String) {
        self.apiKey = apiKey
        self.apiUrl = apiUrl
    }
} 
//
//  LibraryManager.swift
//  MacMusicPlayer
//
//  Created by X on 2024/03/21.
//

import Foundation
import Combine

class LibraryManager: ObservableObject {
    @Published var libraries: [MusicLibrary] = []
    @Published var currentLibrary: MusicLibrary?
    
    init() {
        loadLibraries()
        
        // 如果没有音乐库，尝试迁移现有的单一音乐库
        if libraries.isEmpty {
            migrateExistingSingleLibrary()
        }
        
        // 如果有音乐库，加载最近访问的那个
        if let lastUsedId = UserDefaults.standard.string(forKey: "LastUsedLibraryID"),
           let uuid = UUID(uuidString: lastUsedId),
           let library = libraries.first(where: { $0.id == uuid }) {
            currentLibrary = library
        } else {
            // 否则使用第一个
            currentLibrary = libraries.first
        }
    }
    
    // 添加新音乐库
    func addLibrary(name: String, path: String) {
        let newLibrary = MusicLibrary(
            name: name,
            path: path
        )
        
        libraries.append(newLibrary)
        saveLibraries()
        
        // 自动切换到新添加的音乐库
        switchLibrary(id: newLibrary.id)
    }
    
    // 移除音乐库
    func removeLibrary(id: UUID) {
        // 防止删除最后一个音乐库
        guard libraries.count > 1 else { return }
        
        libraries.removeAll { $0.id == id }
        
        // 如果删除的是当前音乐库，切换到第一个
        if currentLibrary?.id == id {
            currentLibrary = libraries.first
            // 通知刷新音乐库
            NotificationCenter.default.post(name: NSNotification.Name("RefreshMusicLibrary"), object: nil)
        }
        
        saveLibraries()
    }
    
    // 切换音乐库
    func switchLibrary(id: UUID) {
        guard currentLibrary?.id != id,
              let newLibrary = libraries.first(where: { $0.id == id }) else {
            return
        }
        
        // 更新lastAccessed时间
        var updatedLibrary = newLibrary
        updatedLibrary.lastAccessed = Date()
        
        if let index = libraries.firstIndex(where: { $0.id == id }) {
            libraries[index] = updatedLibrary
        }
        
        currentLibrary = updatedLibrary
        
        // 保存最后使用的音乐库ID
        UserDefaults.standard.set(id.uuidString, forKey: "LastUsedLibraryID")
        saveLibraries()
        
        // 通知刷新音乐库
        NotificationCenter.default.post(name: NSNotification.Name("RefreshMusicLibrary"), object: nil)
    }
    
    // 重命名音乐库
    func renameLibrary(id: UUID, newName: String) {
        guard let index = libraries.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        var updatedLibrary = libraries[index]
        updatedLibrary.name = newName
        libraries[index] = updatedLibrary
        
        if currentLibrary?.id == id {
            currentLibrary = updatedLibrary
        }
        
        saveLibraries()
    }
    
    // 保存音乐库信息
    func saveLibraries() {
        do {
            let data = try JSONEncoder().encode(libraries)
            UserDefaults.standard.set(data, forKey: "MusicLibraries")
        } catch {
            print("Failed to save libraries: \(error)")
        }
    }
    
    // 加载保存的音乐库信息
    func loadLibraries() {
        guard let data = UserDefaults.standard.data(forKey: "MusicLibraries") else {
            return
        }
        
        do {
            libraries = try JSONDecoder().decode([MusicLibrary].self, from: data)
        } catch {
            print("Failed to load libraries: \(error)")
        }
    }
    
    // 迁移现有的单一音乐库
    private func migrateExistingSingleLibrary() {
        if let savedPath = UserDefaults.standard.string(forKey: "MusicFolderPath") {
            let defaultLibrary = MusicLibrary(
                id: UUID(),
                name: NSLocalizedString("My Music", comment: "Default music library name"),
                path: savedPath,
                createdAt: Date(),
                lastAccessed: Date()
            )
            
            libraries.append(defaultLibrary)
            currentLibrary = defaultLibrary
            saveLibraries()
        }
    }
} 
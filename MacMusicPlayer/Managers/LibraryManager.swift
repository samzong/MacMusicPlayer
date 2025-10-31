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
        
        // If no music library exists, try migrating existing single music library
        if libraries.isEmpty {
            migrateExistingSingleLibrary()
        }
        
        // If there are music libraries, load the most recently accessed one
        if let lastUsedId = UserDefaults.standard.string(forKey: "LastUsedLibraryID"),
           let uuid = UUID(uuidString: lastUsedId),
           let library = libraries.first(where: { $0.id == uuid }) {
            currentLibrary = library
        } else {
            // Otherwise use the first one
            currentLibrary = libraries.first
        }
    }
    
    // Add new music library
    func addLibrary(name: String, path: String) {
        let newLibrary = MusicLibrary(
            name: name,
            path: path
        )
        
        libraries.append(newLibrary)
        saveLibraries()
        
        // Automatically switch to newly added music library
        switchLibrary(id: newLibrary.id)
    }
    
    // Remove music library
    func removeLibrary(id: UUID) {
        // Prevent deleting the last music library
        guard libraries.count > 1 else { return }
        
        libraries.removeAll { $0.id == id }
        
        // If the deleted library is the current one, switch to the first one
        if currentLibrary?.id == id {
            currentLibrary = libraries.first
            // Notify to refresh music library
            NotificationCenter.default.post(name: NSNotification.Name("RefreshMusicLibrary"), object: nil)
        }
        
        saveLibraries()
    }
    
    // Switch music library
    func switchLibrary(id: UUID) {
        guard currentLibrary?.id != id,
              let newLibrary = libraries.first(where: { $0.id == id }) else {
            return
        }
        
        // Update lastAccessed time
        var updatedLibrary = newLibrary
        updatedLibrary.lastAccessed = Date()
        
        if let index = libraries.firstIndex(where: { $0.id == id }) {
            libraries[index] = updatedLibrary
        }
        
        currentLibrary = updatedLibrary
        
        // Save last used library ID
        UserDefaults.standard.set(id.uuidString, forKey: "LastUsedLibraryID")
        saveLibraries()
        
        // Notify to refresh music library
        NotificationCenter.default.post(name: NSNotification.Name("RefreshMusicLibrary"), object: nil)
    }
    
    // Rename music library
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
    
    // Save music library information
    func saveLibraries() {
        do {
            let data = try JSONEncoder().encode(libraries)
            UserDefaults.standard.set(data, forKey: "MusicLibraries")
        } catch {
            print("Failed to save libraries: \(error)")
        }
    }
    
    // Load saved music library information
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
    
    // Migrate existing single music library
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
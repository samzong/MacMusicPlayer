//
//  MusicLibrary.swift
//  MacMusicPlayer
//
//  Created by X on 2024/03/21.
//

import Foundation

struct MusicLibrary: Identifiable, Codable {
    let id: UUID
    var name: String
    var path: String
    var createdAt: Date
    var lastAccessed: Date
    
    init(id: UUID = UUID(), name: String, path: String, createdAt: Date = Date(), lastAccessed: Date = Date()) {
        self.id = id
        self.name = name
        self.path = path
        self.createdAt = createdAt
        self.lastAccessed = lastAccessed
    }
} 
//
//  PlayerManager.swift
//  MacMusicPlayer
//
//  Created by X on 9/18/24.
//

import Foundation
import AVFoundation
import SwiftUI

class PlayerManager: ObservableObject {
    @Published var playlist: [Track] = []
    @Published var currentTrack: Track?
    @Published var isPlaying = false
    private var player: AVAudioPlayer?
    private var currentIndex = 0
    
    init() {
        requestMusicFolderAccess()
    }
    
    private func requestMusicFolderAccess() {
        let musicFolderURL = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
        
        musicFolderURL.startAccessingSecurityScopedResource()
        
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.directoryURL = musicFolderURL
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.prompt = "Select Music Folder"
            openPanel.message = "Please select your Music folder to allow the app to access your music files."
            
            if openPanel.runModal() == .OK {
                if let selectedURL = openPanel.url {
                    self.loadTracksFromMusicFolder(selectedURL)
                }
            }
            
            musicFolderURL.stopAccessingSecurityScopedResource()
        }
    }
    
    private func loadTracksFromMusicFolder(_ folderURL: URL) {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            let mp3Files = fileURLs.filter { $0.pathExtension.lowercased() == "mp3" }
            
            print("Found \(mp3Files.count) MP3 files")
            
            playlist = mp3Files.compactMap { url in
                let asset = AVAsset(url: url)
                let title = asset.metadata.first(where: { $0.commonKey == .commonKeyTitle })?.stringValue ?? url.lastPathComponent
                let artist = asset.metadata.first(where: { $0.commonKey == .commonKeyArtist })?.stringValue ?? "Unknown"
                
                print("Added track: \(title) by \(artist)")
                
                return Track(id: UUID(), title: title, artist: artist, url: url)
            }
            
            print("Playlist contains \(playlist.count) tracks")
            
            if !playlist.isEmpty {
                currentTrack = playlist[0]
                play()
            }
        } catch {
            print("Error accessing Music folder: \(error)")
        }
    }
    
    func play() {
        guard let track = currentTrack else {
            print("No current track, trying to play next")
            playNext()
            return
        }
        
        if player == nil {
            loadTrack(track)
        }
        
        if player?.play() == true {
            print("Started playing: \(track.title)")
            isPlaying = true
        } else {
            print("Failed to start playback")
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        print("Paused playback")
    }
    
    func playNext() {
        guard !playlist.isEmpty else { return }
        currentIndex = (currentIndex + 1) % playlist.count
        loadTrack(playlist[currentIndex])
        play()
    }
    
    func playPrevious() {
        guard !playlist.isEmpty else { return }
        currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
        loadTrack(playlist[currentIndex])
        play()
    }
    
    private func loadTrack(_ track: Track) {
        do {
            player = try AVAudioPlayer(contentsOf: track.url)
            currentTrack = track
            print("Loaded track: \(track.title)")
        } catch {
            print("Could not load \(track.url): \(error)")
        }
    }
}

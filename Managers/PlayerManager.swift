//
//  PlayerManager.swift
//  MacMusicPlayer
//
//  Created by X on 9/18/24.
//

import Foundation
import AVFoundation
import SwiftUI

class PlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var playlist: [Track] = []
    @Published var currentTrack: Track? {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name("TrackChanged"), object: nil)
        }
    }
    @Published var isPlaying = false {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name("PlaybackStateChanged"), object: nil)
        }
    }
    private var player: AVAudioPlayer?
    private var currentIndex = 0
    
    override init() {
        super.init()
        loadSavedMusicFolder()
    }
    
    private func loadSavedMusicFolder() {
        if let savedPath = UserDefaults.standard.string(forKey: "MusicFolderPath") {
            loadTracksFromMusicFolder(URL(fileURLWithPath: savedPath))
        } else {
            requestMusicFolderAccess()
        }
    }
    
    func requestMusicFolderAccess() {
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.allowsMultipleSelection = false
            openPanel.prompt = "选择音乐文件夹"
            
            if openPanel.runModal() == .OK {
                if let url = openPanel.url {
                    UserDefaults.standard.set(url.path, forKey: "MusicFolderPath")
                    self.loadTracksFromMusicFolder(url)
                }
            }
        }
    }
    
    private func loadTracksFromMusicFolder(_ folderURL: URL) {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            let mp3Files = fileURLs.filter { $0.pathExtension.lowercased() == "mp3" }
            
            playlist = mp3Files.compactMap { url in
                let asset = AVAsset(url: url)
                let title = asset.metadata.first(where: { $0.commonKey == .commonKeyTitle })?.stringValue ?? url.lastPathComponent
                let artist = asset.metadata.first(where: { $0.commonKey == .commonKeyArtist })?.stringValue ?? "Unknown"
                
                return Track(id: UUID(), title: title, artist: artist, url: url)
            }
            
            print("Loaded \(playlist.count) tracks")
            
            if !playlist.isEmpty {
                currentTrack = playlist[0]
                print("Set current track: \(currentTrack?.title ?? "Unknown")")
            }
        } catch {
            print("Error accessing Music folder: \(error)")
        }
    }
    
    func play() {
        guard let track = currentTrack else {
            print("No current track to play")
            return
        }
        
        do {
            player = try AVAudioPlayer(contentsOf: track.url)
            player?.delegate = self // 设置代理
            player?.play()
            isPlaying = true
            print("Started playing: \(track.title)")
        } catch {
            print("Could not create player for \(track.title): \(error)")
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
        currentTrack = playlist[currentIndex]
        play()
    }
    
    func playPrevious() {
        guard !playlist.isEmpty else { return }
        currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
        currentTrack = playlist[currentIndex]
        play()
    }
    
    // AVAudioPlayerDelegate 方法
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            playNext()
        }
    }
}

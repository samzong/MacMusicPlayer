//
//  PlayerManager.swift
//  MacMusicPlayer
//
//  Created by X on 9/18/24.
//

import Foundation
import AVFoundation
import SwiftUI
import MediaPlayer

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
    var audioEngine: AVAudioEngine!
    var playerNode: AVAudioPlayerNode!

    override init() {
        super.init()
        setupAudioEngine()
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

    func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        audioEngine.attach(playerNode)
        let mainMixer = audioEngine.mainMixerNode
        audioEngine.connect(playerNode, to: mainMixer, format: nil)
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        if let currentTrack = currentTrack {
            nowPlayingInfo[MPMediaItemPropertyTitle] = currentTrack.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = currentTrack.artist
            
            if let player = player {
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.duration
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.isPlaying ? 1.0 : 0.0
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
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
        
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        print("Paused playback")
        
        updateNowPlayingInfo()
    }

    func playNext() {
        guard !playlist.isEmpty else { return }
        currentIndex = (currentIndex + 1) % playlist.count
        currentTrack = playlist[currentIndex]
        play()
        
        updateNowPlayingInfo()
    }

    func playPrevious() {
        guard !playlist.isEmpty else { return }
        currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
        currentTrack = playlist[currentIndex]
        play()
        
        updateNowPlayingInfo()
    }

    // AVAudioPlayerDelegate 方法
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            playNext()
        }
    }
}

//
//  PlayerManager.swift
//  MacMusicPlayer
//
//  Created by X on 2024/09/18.
//

import Foundation
import AVFoundation
import SwiftUI
import MediaPlayer

class PlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var playlist: [Track] = []
    @Published var currentTrack: Track? {
        didSet {
            player = nil  // Reset player when track changes
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
    
    // Equalizer related attributes
    private var bassEQ: AVAudioUnitEQ!
    private var midEQ: AVAudioUnitEQ!
    private var trebleEQ: AVAudioUnitEQ!
    
    @Published var bassGain: Float = 0.0 {
        didSet {
            updateBassEQ()
            UserDefaults.standard.set(bassGain, forKey: "BassGain")
        }
    }
    
    @Published var midGain: Float = 0.0 {
        didSet {
            updateMidEQ()
            UserDefaults.standard.set(midGain, forKey: "MidGain")
        }
    }
    
    @Published var trebleGain: Float = 0.0 {
        didSet {
            updateTrebleEQ()
            UserDefaults.standard.set(trebleGain, forKey: "TrebleGain")
        }
    }
    
    @Published var equalizerEnabled: Bool = false {
        didSet {
            updateEqualizerState()
            UserDefaults.standard.set(equalizerEnabled, forKey: "EqualizerEnabled")
        }
    }
    
    // 均衡器预设
    enum EqualizerPreset: String, CaseIterable {
        case flat = "Flat"
        case classical = "Classical"
        case rock = "Rock"
        case pop = "Pop"
        case jazz = "Jazz"
        case electronic = "Electronic"
        case hiphop = "Hip-Hop"
        
        var localizedString: String {
            return NSLocalizedString(self.rawValue, comment: "")
        }
        
        var settings: (bass: Float, mid: Float, treble: Float) {
            switch self {
            case .flat:
                return (0.0, 0.0, 0.0)
            case .classical:
                return (0.0, 0.0, 3.0)  // Slight increase in treble to enhance clarity
            case .rock:
                return (3.0, 0.0, 3.0)  // Enhanced bass and treble
            case .pop:
                return (1.0, 2.0, 2.0)  // Slight increase in bass, more prominent mid and treble
            case .jazz:
                return (2.0, -1.0, 1.0) // Enhanced bass, reduced mid, slight increase in treble
            case .electronic:
                return (4.0, 0.0, 2.0)  // Emphasize bass and treble
            case .hiphop:
                return (5.0, -1.0, 0.0) // Emphasize bass, reduced mid
            }
        }
    }
    
    @Published var currentPreset: EqualizerPreset = .flat {
        didSet {
            applyPreset(currentPreset)
            UserDefaults.standard.set(currentPreset.rawValue, forKey: "EqualizerPreset")
        }
    }

    enum PlayMode: String {
        case sequential = "Sequential"
        case singleLoop = "Single Loop"
        case random = "Random"
        
        var localizedString: String {
            return NSLocalizedString(self.rawValue, comment: "")
        }
    }

    @Published var playMode: PlayMode = .sequential {
        didSet {
            UserDefaults.standard.set(playMode.rawValue, forKey: "PlayMode")
            NotificationCenter.default.post(name: NSNotification.Name("PlayModeChanged"), object: nil)
        }
    }

    override init() {
        if let savedMode = UserDefaults.standard.string(forKey: "PlayMode"),
           let mode = PlayMode(rawValue: savedMode) {
            playMode = mode
        } else {
            playMode = .sequential
        }
        
        // 加载均衡器设置
        if UserDefaults.standard.object(forKey: "BassGain") != nil {
            bassGain = UserDefaults.standard.float(forKey: "BassGain")
        }
        
        if UserDefaults.standard.object(forKey: "MidGain") != nil {
            midGain = UserDefaults.standard.float(forKey: "MidGain")
        }
        
        if UserDefaults.standard.object(forKey: "TrebleGain") != nil {
            trebleGain = UserDefaults.standard.float(forKey: "TrebleGain")
        }
        
        if UserDefaults.standard.object(forKey: "EqualizerEnabled") != nil {
            equalizerEnabled = UserDefaults.standard.bool(forKey: "EqualizerEnabled")
        }
        
        if let savedPreset = UserDefaults.standard.string(forKey: "EqualizerPreset"),
           let preset = EqualizerPreset(rawValue: savedPreset) {
            currentPreset = preset
        } else {
            currentPreset = .flat
        }
        
        super.init()
        
        // Listen for music library refresh notification
        NotificationCenter.default.addObserver(self,
                                            selector: #selector(refreshMusicLibrary),
                                            name: NSNotification.Name("RefreshMusicLibrary"),
                                            object: nil)
        
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
            openPanel.prompt = NSLocalizedString("Select Music Folder", comment: "")
            
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
        
        setupEqualizer()
        
        audioEngine.attach(playerNode)
        audioEngine.attach(bassEQ)
        audioEngine.attach(midEQ)
        audioEngine.attach(trebleEQ)
        
        let mainMixer = audioEngine.mainMixerNode
        
        if equalizerEnabled {
            audioEngine.connect(playerNode, to: bassEQ, format: nil)
            audioEngine.connect(bassEQ, to: midEQ, format: nil)
            audioEngine.connect(midEQ, to: trebleEQ, format: nil)
            audioEngine.connect(trebleEQ, to: mainMixer, format: nil)
        } else {
            audioEngine.connect(playerNode, to: mainMixer, format: nil)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func setupEqualizer() {
        bassEQ = AVAudioUnitEQ(numberOfBands: 1)
        let bassParams = bassEQ.bands[0]
        bassParams.filterType = .parametric
        bassParams.frequency = 100
        bassParams.bandwidth = 1.0
        bassParams.gain = bassGain
        
        midEQ = AVAudioUnitEQ(numberOfBands: 1)
        let midParams = midEQ.bands[0]
        midParams.filterType = .parametric
        midParams.frequency = 1000
        midParams.bandwidth = 1.0
        midParams.gain = midGain
        
        trebleEQ = AVAudioUnitEQ(numberOfBands: 1)
        let trebleParams = trebleEQ.bands[0]
        trebleParams.filterType = .parametric
        trebleParams.frequency = 10000
        trebleParams.bandwidth = 1.0
        trebleParams.gain = trebleGain
    }
    
    private func updateBassEQ() {
        bassEQ.bands[0].gain = bassGain
    }
    
    private func updateMidEQ() {
        midEQ.bands[0].gain = midGain
    }
    
    private func updateTrebleEQ() {
        trebleEQ.bands[0].gain = trebleGain
    }
    
    private func updateEqualizerState() {
        audioEngine.stop()
        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.disconnectNodeOutput(bassEQ)
        audioEngine.disconnectNodeOutput(midEQ)
        audioEngine.disconnectNodeOutput(trebleEQ)
        
        let mainMixer = audioEngine.mainMixerNode
        
        if equalizerEnabled {
            audioEngine.connect(playerNode, to: bassEQ, format: nil)
            audioEngine.connect(bassEQ, to: midEQ, format: nil)
            audioEngine.connect(midEQ, to: trebleEQ, format: nil)
            audioEngine.connect(trebleEQ, to: mainMixer, format: nil)
        } else {
            audioEngine.connect(playerNode, to: mainMixer, format: nil)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to restart audio engine: \(error)")
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
                let artist = asset.metadata.first(where: { $0.commonKey == .commonKeyArtist })?.stringValue ?? NSLocalizedString("Unknown Artist", comment: "")
                
                return Track(id: UUID(), title: title, artist: artist, url: url)
            }
            
            print("Loaded \(playlist.count) tracks")
            
            if !playlist.isEmpty {
                currentTrack = playlist[0]
                print("Set current track: \(currentTrack?.title ?? "Unknown")")
            }
        } catch {
            print(NSLocalizedString("Error accessing Music folder", comment: ""))
        }
    }

    func play() {
        guard let track = currentTrack else {
            print(NSLocalizedString("No current track to play", comment: ""))
            return
        }
        
        if player == nil {
            do {
                player = try AVAudioPlayer(contentsOf: track.url)
                player?.delegate = self
            } catch {
                print(NSLocalizedString("Could not create player", comment: "") + " \(track.title): \(error)")
                return
            }
        }
        
        player?.play()
        isPlaying = true
        print(NSLocalizedString("Started playing", comment: "") + ": \(track.title)")
        
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        print(NSLocalizedString("Paused playback", comment: ""))
        
        updateNowPlayingInfo()
    }

    func playNext() {
        guard !playlist.isEmpty else { return }
        
        switch playMode {
        case .sequential:
            currentIndex = (currentIndex + 1) % playlist.count
        case .singleLoop:
            break
        case .random:
            currentIndex = Int.random(in: 0..<playlist.count)
        }
        
        currentTrack = playlist[currentIndex]
        play()
        updateNowPlayingInfo()
    }

    func playPrevious() {
        guard !playlist.isEmpty else { return }
        
        switch playMode {
        case .sequential, .random:
            currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
        case .singleLoop:
            break
        }
        
        currentTrack = playlist[currentIndex]
        play()
        updateNowPlayingInfo()
    }

    // AVAudioPlayerDelegate methods
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            switch playMode {
            case .sequential:
                if currentIndex < playlist.count - 1 {
                    playNext()
                }
            case .singleLoop:
                play()
            case .random:
                playNext()
            }
        }
    }

    @objc private func refreshMusicLibrary() {
        loadSavedMusicFolder()
    }

    func applyPreset(_ preset: EqualizerPreset) {
        let settings = preset.settings
        bassGain = settings.bass
        midGain = settings.mid
        trebleGain = settings.treble
    }
}

extension PlayerManager.PlayMode {
    var tag: Int {
        switch self {
        case .sequential: return 0
        case .singleLoop: return 1
        case .random: return 2
        }
    }
}

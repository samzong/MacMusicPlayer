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

class PlayerManager: NSObject, ObservableObject {
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

    // New queue-based architecture
    private let queueController: QueuePlayerController
    private let playlistStore: PlaylistStore

    // Legacy currentIndex for backward compatibility during transition
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

    // Direct volume control - no temporary caches
    var volume: Float {
        get { queueController.volume }
        set {
            queueController.volume = newValue
            UserDefaults.standard.set(newValue, forKey: "SavedVolume")
        }
    }


    @Published var playMode: PlayMode = .sequential {
        didSet {
            UserDefaults.standard.set(playMode.rawValue, forKey: "PlayMode")
            NotificationCenter.default.post(name: NSNotification.Name("PlayModeChanged"), object: nil)
        }
    }

    override init() {
        // Initialize queue-based architecture first
        queueController = QueuePlayerController()
        playlistStore = PlaylistStore()

        if let savedMode = UserDefaults.standard.string(forKey: "PlayMode"),
           let mode = PlayMode(rawValue: savedMode) {
            playMode = mode
        } else {
            playMode = .sequential
        }

        // Load equalizer settings
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

        // Initialize saved volume with default if first launch
        let savedVolume: Float
        if UserDefaults.standard.object(forKey: "SavedVolume") == nil {
            savedVolume = 0.3
            UserDefaults.standard.set(savedVolume, forKey: "SavedVolume")
        } else {
            savedVolume = UserDefaults.standard.float(forKey: "SavedVolume")
        }

        // Wire up queue controller callbacks
        queueController.onTrackChanged = { [weak self] track in
            guard let self = self else { return }
            self.currentTrack = track

            // Sync PlaylistStore currentIndex with queue controller track changes
            if let track = track,
               let trackIndex = self.playlistStore.tracks.firstIndex(where: { $0.id == track.id }) {
                self.playlistStore.setCurrentIndex(trackIndex)
                self.currentIndex = trackIndex
            }

            // Ensure Now Playing metadata stays in sync for automatic transitions
            self.updateNowPlayingInfo()
        }

        queueController.onPlaybackStateChanged = { [weak self] playing in
            self?.isPlaying = playing
        }

        queueController.onTrackFinished = { [weak self] finishedTrack in
            self?.handleAutomaticTrackCompletion(finishedTrack)
        }

        // Set initial volume from saved preferences
        queueController.volume = savedVolume

        // Listen for music library refresh notification
        NotificationCenter.default.addObserver(self,
                                            selector: #selector(refreshMusicLibrary),
                                            name: NSNotification.Name("RefreshMusicLibrary"),
                                            object: nil)

        setupAudioEngine()
        loadSavedMusicFolder()
    }

    private func loadSavedMusicFolder() {
        // 什么都不做，现在由LibraryManager控制
    }

    func requestMusicFolderAccess() {
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.allowsMultipleSelection = false
            openPanel.prompt = NSLocalizedString("Select Music Folder", comment: "Open panel prompt for selecting music folder")
            
            if openPanel.runModal() == .OK {
                if let url = openPanel.url {
                    let name = url.lastPathComponent
                    
                    // 创建新的音乐库
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AddNewLibrary"),
                        object: nil,
                        userInfo: ["name": name, "path": url.path]
                    )
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

        if let currentTrack = queueController.currentTrack ?? currentTrack {
            nowPlayingInfo[MPMediaItemPropertyTitle] = currentTrack.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = currentTrack.artist
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = queueController.isPlaying ? 1.0 : 0.0

            if let duration = queueController.currentItemDuration {
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            }

            if let elapsed = queueController.currentItemElapsedTime {
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func loadLibrary(_ library: MusicLibrary) {
        // Clear current queue and stop playback
        queueController.clearQueue()
        currentTrack = nil
        isPlaying = false
        currentIndex = 0

        // Legacy playlist for backward compatibility during migration
        playlist = []

        // 加载新音乐库的音乐文件
        loadTracksFromMusicFolder(URL(fileURLWithPath: library.path))
    }
    
    func loadTracksFromMusicFolder(_ folderURL: URL) {
        let fileManager = FileManager.default
        
        // 获取文件夹的所有内容
        guard let enumerator = fileManager.enumerator(at: folderURL,
                                                    includingPropertiesForKeys: [.isRegularFileKey],
                                                    options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            print("Failed to enumerate folder contents")
            return
        }
        
        var newPlaylist: [Track] = []
        
        for case let fileURL as URL in enumerator {
            // 检查文件类型是否为音频文件
            if isAudioFile(fileURL) {
                let fileName = fileURL.deletingPathExtension().lastPathComponent
                
                // 简单处理：使用文件名作为标题，如果有 " - " 则分为艺术家和标题
                var title = fileName
                var artist = NSLocalizedString("Unknown Artist", comment: "Default artist name when parsing filenames")
                
                if let range = fileName.range(of: " - ") {
                    artist = String(fileName[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                    title = String(fileName[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                }
                
                let track = Track(id: UUID(), title: title, artist: artist, url: fileURL)
                newPlaylist.append(track)
            }
        }
        
        // 更新播放列表
        DispatchQueue.main.async {
            // 排序播放列表（按标题）
            let sortedTracks = newPlaylist.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

            // Update PlaylistStore (new architecture)
            self.playlistStore.setTracks(sortedTracks)

            // Legacy playlist for backward compatibility
            self.playlist = sortedTracks

            // 如果有歌曲则设置第一首为当前歌曲
            if !sortedTracks.isEmpty {
                self.currentIndex = 0
                self.currentTrack = sortedTracks[0]
                // Set up queue with all tracks starting at index 0
                self.queueController.setQueue(sortedTracks, startingAt: 0)
            }
        }
    }
    
    private func isAudioFile(_ url: URL) -> Bool {
        let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "aiff"]
        return audioExtensions.contains(url.pathExtension.lowercased())
    }

    func play() {
        guard let track = currentTrack else {
            print(NSLocalizedString("No current track to play", comment: ""))
            return
        }

        // Use queue controller for new architecture
        queueController.play()

        print(NSLocalizedString("Started playing", comment: "") + ": \(track.title)")

        updateNowPlayingInfo()
    }

    func pause() {
        queueController.pause()
        print(NSLocalizedString("Paused playback", comment: ""))
        updateNowPlayingInfo()
    }

    func stop() {
        // Queue controller stop (pause + seek to 0, non-destructive)
        queueController.stop()
        updateNowPlayingInfo()
    }

    func playTrack(at index: Int) {
        guard index >= 0 && index < playlistStore.tracks.count else { return }

        let tracks = playlistStore.tracks
        queueController.setQueue(tracks, startingAt: index)
        playlistStore.setCurrentIndex(index)
        currentIndex = index
        currentTrack = tracks[index]
        queueController.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func clearQueue() {
        // Clear queue controller (destructive)
        queueController.clearQueue()
        currentTrack = nil
        isPlaying = false
        currentIndex = 0
        updateNowPlayingInfo()
    }

    func playNext() {
        guard !playlistStore.isEmpty else { return }

        // Get next index based on play mode from PlaylistStore
        guard let nextIndex = playlistStore.nextIndex(for: playMode) else {
            // No next track available (e.g., end of sequential playlist)
            return
        }

        // Update PlaylistStore current index
        playlistStore.setCurrentIndex(nextIndex)

        // Use queue controller advance or rebuild queue for complex modes
        switch playMode {
        case .sequential:
            if queueController.advanceToNext() {
                // Successfully advanced in queue
                currentIndex = nextIndex
            } else {
                // End of queue, wrap around - rebuild queue
                queueController.setQueue(playlistStore.tracks, startingAt: 0)
                playlistStore.setCurrentIndex(0)
                currentIndex = 0
                queueController.play()
            }
        case .singleLoop:
            // Restart current track
            queueController.stop()
            queueController.play()
        case .random:
            // Rebuild queue starting at random index
            queueController.setQueue(playlistStore.tracks, startingAt: nextIndex)
            currentIndex = nextIndex
            queueController.play()
        }

        // Legacy update for backward compatibility
        currentTrack = playlistStore.currentTrack

        updateNowPlayingInfo()
    }

    func playPrevious() {
        guard !playlistStore.isEmpty else { return }

        switch playMode {
        case .sequential, .random:
            guard let previousIndex = playlistStore.previousIndex() else { return }

            // Rebuild queue for previous track (AVQueuePlayer limitation)
            queueController.setQueue(playlistStore.tracks, startingAt: previousIndex)
            playlistStore.setCurrentIndex(previousIndex)
            currentIndex = previousIndex
            queueController.play()

            // Legacy update
            currentTrack = playlistStore.currentTrack
        case .singleLoop:
            // Restart current track
            queueController.stop()
            queueController.play()
        }

        updateNowPlayingInfo()
    }


    @objc func refreshMusicLibrary() {
        // 判断是否有当前库
        if let library = (NSApplication.shared.delegate as? AppDelegate)?.libraryManager.currentLibrary {
            loadLibrary(library)
        } else {
            loadSavedMusicFolder()
        }
    }

    func applyPreset(_ preset: EqualizerPreset) {
        let settings = preset.settings
        bassGain = settings.bass
        midGain = settings.mid
        trebleGain = settings.treble
    }

    private func handleAutomaticTrackCompletion(_ finishedTrack: Track?) {
        guard !playlistStore.isEmpty else { return }

        switch playMode {
        case .sequential:
            guard
                let finishedTrack,
                let finishedIndex = playlistStore.tracks.firstIndex(where: { $0.id == finishedTrack.id })
            else { return }

            if finishedIndex == playlistStore.count - 1 {
                // Last track finished – rebuild queue from the top to loop
                let nextIndex = (finishedIndex + 1) % playlistStore.count
                queueController.setQueue(playlistStore.tracks, startingAt: nextIndex)
                queueController.play()
                updateNowPlayingInfo()
            }

        case .singleLoop:
            guard
                let finishedTrack,
                let finishedIndex = playlistStore.tracks.firstIndex(where: { $0.id == finishedTrack.id })
            else { return }

            playlistStore.setCurrentIndex(finishedIndex)
            currentIndex = finishedIndex
            currentTrack = playlistStore.currentTrack

            queueController.setQueue(playlistStore.tracks, startingAt: finishedIndex)
            queueController.play()
            updateNowPlayingInfo()

        case .random:
            // Pick a truly random next track and rebuild queue
            guard let nextIndex = playlistStore.nextIndex(for: playMode) else { return }

            // Rebuild queue starting from the random track
            queueController.setQueue(playlistStore.tracks, startingAt: nextIndex)
            playlistStore.setCurrentIndex(nextIndex)
            currentIndex = nextIndex
            queueController.play()

            // Update UI state
            currentTrack = playlistStore.currentTrack
            updateNowPlayingInfo()
        }
    }
}

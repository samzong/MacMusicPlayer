import Foundation
import Combine
import AppKit
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

    private let queueController: QueuePlayerController
    private let playlistStore: PlaylistStore

    var hasPlaylist: Bool { !playlistStore.isEmpty }

    private var currentIndex = 0
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
        queueController = QueuePlayerController()
        playlistStore = PlaylistStore()

        if let savedMode = UserDefaults.standard.string(forKey: "PlayMode"),
           let mode = PlayMode(rawValue: savedMode) {
            playMode = mode
        } else {
            playMode = .sequential
        }

        super.init()

        let savedVolume: Float
        if UserDefaults.standard.object(forKey: "SavedVolume") == nil {
            savedVolume = 0.3
            UserDefaults.standard.set(savedVolume, forKey: "SavedVolume")
        } else {
            savedVolume = UserDefaults.standard.float(forKey: "SavedVolume")
        }

        queueController.onTrackChanged = { [weak self] track in
            guard let self = self else { return }
            self.currentTrack = track

            if let track = track,
               let trackIndex = self.playlistStore.tracks.firstIndex(where: { $0.id == track.id }) {
                self.playlistStore.setCurrentIndex(trackIndex)
                self.currentIndex = trackIndex
            }

            self.updateNowPlayingInfo()
        }

        queueController.onPlaybackStateChanged = { [weak self] playing in
            self?.isPlaying = playing
        }

        queueController.onTrackFinished = { [weak self] finishedTrack in
            self?.handleAutomaticTrackCompletion(finishedTrack)
        }

        queueController.volume = savedVolume

        NotificationCenter.default.addObserver(self,
                                            selector: #selector(refreshMusicLibrary),
                                            name: NSNotification.Name("RefreshMusicLibrary"),
                                            object: nil)

        loadSavedMusicFolder()
    }

    private func loadSavedMusicFolder() {
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

                    NotificationCenter.default.post(
                        name: NSNotification.Name("AddNewLibrary"),
                        object: nil,
                        userInfo: ["name": name, "path": url.path]
                    )
                }
            }
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
        queueController.clearQueue()
        currentTrack = nil
        isPlaying = false
        currentIndex = 0

        playlist = []

        loadTracksFromMusicFolder(URL(fileURLWithPath: library.path))
    }

    func loadTracksFromMusicFolder(_ folderURL: URL) {
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(at: folderURL,
                                                    includingPropertiesForKeys: [.isRegularFileKey],
                                                    options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            print("Failed to enumerate folder contents")
            return
        }

        var newPlaylist: [Track] = []

        for case let fileURL as URL in enumerator {
            if isAudioFile(fileURL) {
                let fileName = fileURL.deletingPathExtension().lastPathComponent

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

        DispatchQueue.main.async {
            let sortedTracks = newPlaylist.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

            self.playlistStore.setTracks(sortedTracks)

            self.playlist = sortedTracks

            if !sortedTracks.isEmpty {
                self.currentIndex = 0
                self.currentTrack = sortedTracks[0]
                self.playlistStore.setCurrentIndex(0)
                self.queueController.setQueue(sortedTracks, startingAt: 0)
            } else {
                self.currentTrack = nil
                self.currentIndex = 0
            }

            NotificationCenter.default.post(name: NSNotification.Name("PlaylistUpdated"), object: nil)
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
        queueController.clearQueue()
        currentTrack = nil
        isPlaying = false
        currentIndex = 0
        updateNowPlayingInfo()
    }

    func playNext() {
        guard !playlistStore.isEmpty else { return }

        guard let nextIndex = playlistStore.nextIndex(for: playMode) else {
            return
        }

        playlistStore.setCurrentIndex(nextIndex)

        switch playMode {
        case .sequential:
            if queueController.advanceToNext() {
                currentIndex = nextIndex
            } else {
                queueController.setQueue(playlistStore.tracks, startingAt: 0)
                playlistStore.setCurrentIndex(0)
                currentIndex = 0
                queueController.play()
            }
        case .singleLoop:
            queueController.stop()
            queueController.play()
        case .random:
            queueController.setQueue(playlistStore.tracks, startingAt: nextIndex)
            currentIndex = nextIndex
            queueController.play()
        }

        currentTrack = playlistStore.currentTrack

        updateNowPlayingInfo()
    }

    func playPrevious() {
        guard !playlistStore.isEmpty else { return }

        switch playMode {
        case .sequential, .random:
            guard let previousIndex = playlistStore.previousIndex() else { return }

            queueController.setQueue(playlistStore.tracks, startingAt: previousIndex)
            playlistStore.setCurrentIndex(previousIndex)
            currentIndex = previousIndex
            queueController.play()

            currentTrack = playlistStore.currentTrack
        case .singleLoop:
            queueController.stop()
            queueController.play()
        }

        updateNowPlayingInfo()
    }


    @MainActor
    @objc func refreshMusicLibrary() {
        if let library = (NSApplication.shared.delegate as? AppDelegate)?.libraryManager.currentLibrary {
            loadLibrary(library)
        } else {
            loadSavedMusicFolder()
        }
    }


    func feelingLucky() {
        guard !playlistStore.isEmpty else { return }

        var randomIndex = Int.random(in: 0..<playlistStore.count)
        if playlistStore.count > 1 {
            while randomIndex == playlistStore.currentIndex {
                randomIndex = Int.random(in: 0..<playlistStore.count)
            }
        }

        playTrack(at: randomIndex)
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
            guard let nextIndex = playlistStore.nextIndex(for: playMode) else { return }

            queueController.setQueue(playlistStore.tracks, startingAt: nextIndex)
            playlistStore.setCurrentIndex(nextIndex)
            currentIndex = nextIndex
            queueController.play()

            currentTrack = playlistStore.currentTrack
            updateNowPlayingInfo()
        }
    }
}

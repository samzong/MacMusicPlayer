//
//  QueuePlayerController.swift
//  MacMusicPlayer
//
//  Created by X on 2024/09/23.
//

import Foundation
import AVFoundation

class QueuePlayerController: NSObject, PlaybackControlling {
    private let queuePlayer: AVQueuePlayer
    private var playerItems: [AVPlayerItem] = []
    private var tracks: [Track] = []
    private var currentTrackIndex: Int = 0

    var onTrackChanged: ((Track?) -> Void)?
    var onPlaybackStateChanged: ((Bool) -> Void)?
    var onTrackFinished: ((Track?) -> Void)?

    var isPlaying: Bool {
        queuePlayer.rate > 0
    }

    var currentTrack: Track? {
        guard currentTrackIndex < tracks.count else { return nil }
        return tracks[currentTrackIndex]
    }

    var volume: Float {
        get { queuePlayer.volume }
        set { queuePlayer.volume = newValue }
    }

    var currentItemDuration: TimeInterval? {
        guard let duration = queuePlayer.currentItem?.asset.duration else { return nil }
        let seconds = CMTimeGetSeconds(duration)
        return seconds.isFinite ? seconds : nil
    }

    var currentItemElapsedTime: TimeInterval? {
        let currentTime = queuePlayer.currentTime()
        let seconds = CMTimeGetSeconds(currentTime)
        return seconds.isFinite ? seconds : nil
    }

    override init() {
        queuePlayer = AVQueuePlayer()
        super.init()
        setupObservers()
    }

    deinit {
        removeObservers()
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )

        queuePlayer.addObserver(self, forKeyPath: "rate", options: [.new], context: nil)
        queuePlayer.addObserver(self, forKeyPath: "currentItem", options: [.new], context: nil)
    }

    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        queuePlayer.removeObserver(self, forKeyPath: "rate")
        queuePlayer.removeObserver(self, forKeyPath: "currentItem")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            onPlaybackStateChanged?(isPlaying)
        } else if keyPath == "currentItem" {
            updateCurrentTrackIndex()
            onTrackChanged?(currentTrack)
        }
    }

    @objc private func playerItemDidFinish(_ notification: Notification) {
        guard let finishedItem = notification.object as? AVPlayerItem,
              let index = playerItems.firstIndex(of: finishedItem),
              index < tracks.count else {
            return
        }

        onTrackFinished?(tracks[index])
    }

    private func updateCurrentTrackIndex() {
        guard let currentItem = queuePlayer.currentItem,
              let index = playerItems.firstIndex(of: currentItem) else {
            return
        }
        currentTrackIndex = index
    }

    // MARK: - PlaybackControlling Implementation

    func play() {
        queuePlayer.play()
    }

    func pause() {
        queuePlayer.pause()
    }

    func stop() {
        queuePlayer.pause()
        queuePlayer.seek(to: .zero)
    }

    func clearQueue() {
        queuePlayer.removeAllItems()
        playerItems.removeAll()
        tracks.removeAll()
        currentTrackIndex = 0
    }

    func setQueue(_ tracks: [Track], startingAt index: Int) {
        clearQueue()

        guard !tracks.isEmpty else { return }

        self.tracks = tracks

        var newPlayerItems: [AVPlayerItem] = []
        newPlayerItems.reserveCapacity(tracks.count)

        for track in tracks {
            let playerItem = createPlayerItem(from: track)
            newPlayerItems.append(playerItem)
        }

        guard !newPlayerItems.isEmpty else { return }

        playerItems = newPlayerItems

        let boundedIndex = max(0, min(index, playerItems.count - 1))
        currentTrackIndex = boundedIndex

        let orderedIndices = Array(boundedIndex..<playerItems.count) + Array(0..<boundedIndex)

        for trackIndex in orderedIndices {
            let playerItem = playerItems[trackIndex]
            queuePlayer.insert(playerItem, after: queuePlayer.items().last)
        }
    }

    func advanceToNext() -> Bool {
        guard currentTrackIndex < tracks.count - 1 else { return false }
        queuePlayer.advanceToNextItem()
        return true
    }

    func goToPrevious() -> Bool {
        // AVQueuePlayer doesn't support going backwards, so we need to rebuild the queue
        guard currentTrackIndex > 0 else { return false }

        let newIndex = currentTrackIndex - 1
        setQueue(tracks, startingAt: newIndex)
        return true
    }

    private func createPlayerItem(from track: Track) -> AVPlayerItem {
        return AVPlayerItem(url: track.url)
    }
}

import Foundation
import AVFoundation

class QueuePlayerController: NSObject, PlaybackControlling {
    private let queuePlayer: AVQueuePlayer
    private var itemIndices: [ObjectIdentifier: Int] = [:]
    private var tracks: [Track] = []
    private var currentTrackIndex: Int = 0
    private var currentItemStatusObservation: NSKeyValueObservation?

    var onTrackChanged: ((Track?) -> Void)?
    var onPlaybackStateChanged: ((Bool) -> Void)?
    var onTrackFinished: ((Track?) -> Void)?

    var isPlaying: Bool {
        guard let currentItem = queuePlayer.currentItem else { return false }
        return currentItem.status != .failed && queuePlayer.rate > 0
    }

    var currentTrack: Track? {
        guard let currentItem = queuePlayer.currentItem,
              currentItem.status != .failed,
              currentTrackIndex < tracks.count else { return nil }
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
        currentItemStatusObservation = nil
        NotificationCenter.default.removeObserver(self)
        queuePlayer.removeObserver(self, forKeyPath: "rate")
        queuePlayer.removeObserver(self, forKeyPath: "currentItem")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            onPlaybackStateChanged?(isPlaying)
        } else if keyPath == "currentItem" {
            observeCurrentItemStatus()
            guard queuePlayer.currentItem != nil else { return }
            updateCurrentTrackIndex()
            appendNextItemIfNeeded()
            onTrackChanged?(currentTrack)
            onPlaybackStateChanged?(isPlaying)
        }
    }

    private func observeCurrentItemStatus() {
        currentItemStatusObservation = queuePlayer.currentItem?.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .failed else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.queuePlayer.currentItem == nil || self.queuePlayer.currentItem === item else { return }
                self.onTrackChanged?(nil)
                self.onPlaybackStateChanged?(false)
            }
        }
    }

    @objc private func playerItemDidFinish(_ notification: Notification) {
        guard let finishedItem = notification.object as? AVPlayerItem,
              let index = itemIndices.removeValue(forKey: ObjectIdentifier(finishedItem)),
              index < tracks.count else {
            return
        }

        onTrackFinished?(tracks[index])
    }

    private func updateCurrentTrackIndex() {
        guard let currentItem = queuePlayer.currentItem,
              let index = itemIndices[ObjectIdentifier(currentItem)] else {
            return
        }
        currentTrackIndex = index
    }


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
        itemIndices.removeAll()
        tracks.removeAll()
        currentTrackIndex = 0
    }

    func setQueue(_ tracks: [Track], startingAt index: Int) {
        clearQueue()

        guard !tracks.isEmpty else { return }

        self.tracks = tracks
        currentTrackIndex = max(0, min(index, tracks.count - 1))
        appendItem(at: currentTrackIndex)
        appendNextItemIfNeeded()
    }

    func advanceToNext() -> Bool {
        guard currentTrackIndex < tracks.count - 1 else { return false }
        appendNextItemIfNeeded()
        if let currentItem = queuePlayer.currentItem {
            itemIndices.removeValue(forKey: ObjectIdentifier(currentItem))
        }
        queuePlayer.advanceToNextItem()
        return true
    }

    private func appendNextItemIfNeeded() {
        guard queuePlayer.items().count < 2 else { return }
        let nextIndex = currentTrackIndex + 1
        guard nextIndex < tracks.count else { return }
        appendItem(at: nextIndex)
    }

    private func appendItem(at index: Int) {
        let item = AVPlayerItem(url: tracks[index].url)
        itemIndices[ObjectIdentifier(item)] = index
        queuePlayer.insert(item, after: queuePlayer.items().last)
    }
}

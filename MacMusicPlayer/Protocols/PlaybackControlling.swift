import Foundation
import AVFoundation

protocol PlaybackControlling {
    var isPlaying: Bool { get }
    var currentTrack: Track? { get }
    var volume: Float { get set }
    var currentItemDuration: TimeInterval? { get }
    var currentItemElapsedTime: TimeInterval? { get }

    func play()
    func pause()
    func stop()
    func clearQueue()

    func setQueue(_ tracks: [Track], startingAt index: Int)
    func advanceToNext() -> Bool

    var onTrackChanged: ((Track?) -> Void)? { get set }
    var onPlaybackStateChanged: ((Bool) -> Void)? { get set }
    var onTrackFinished: ((Track?) -> Void)? { get set }
}

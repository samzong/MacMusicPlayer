import XCTest
@testable import MacMusicPlayer

final class QueuePlayerControllerTests: XCTestCase {
    @MainActor
    func testFailedQueueClearsTrackAndPlaybackState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("broken.wav")
        try Data("not an audio file".utf8).write(to: url)
        let controller = QueuePlayerController()
        let cleared = expectation(description: "Failed queue clears its current track")
        let stopped = expectation(description: "Failed queue reports stopped playback")
        var observedTrack = false
        var didClear = false
        var didStop = false
        controller.onTrackChanged = { track in
            if track != nil { observedTrack = true }
            if observedTrack, track == nil, !didClear {
                didClear = true
                cleared.fulfill()
            }
        }
        controller.onPlaybackStateChanged = { playing in
            if didClear, !playing, !didStop {
                didStop = true
                stopped.fulfill()
            }
        }
        controller.setQueue([Track(id: UUID(), title: "Broken", artist: "", url: url)], startingAt: 0)
        controller.play()

        wait(for: [cleared, stopped], timeout: 5)

        XCTAssertNil(controller.currentTrack)
        XCTAssertFalse(controller.isPlaying)
    }
}

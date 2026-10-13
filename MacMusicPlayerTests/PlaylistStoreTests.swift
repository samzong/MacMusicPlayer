import XCTest
@testable import MacMusicPlayer

final class PlaylistStoreTests: XCTestCase {
    private func makeStore(count: Int, current: Int = 0) -> PlaylistStore {
        let store = PlaylistStore()
        store.setTracks((0..<count).map {
            Track(id: UUID(), title: "Title \($0)", artist: "Artist", url: URL(fileURLWithPath: "/music/\($0).mp3"))
        })
        store.setCurrentIndex(current)
        return store
    }

    func testSetTracksResetsIndex() {
        let store = makeStore(count: 3, current: 2)
        store.setTracks([])
        XCTAssertTrue(store.isEmpty)
        XCTAssertNil(store.currentTrack)
    }

    func testSetCurrentIndexRejectsOutOfRange() {
        let store = makeStore(count: 3, current: 1)
        store.setCurrentIndex(7)
        store.setCurrentIndex(-1)
        XCTAssertEqual(store.currentIndex, 1)
    }

    func testSequentialNextAdvancesAndWraps() {
        let store = makeStore(count: 3, current: 0)
        XCTAssertEqual(store.nextIndex(for: .sequential), 1)
        store.setCurrentIndex(2)
        XCTAssertEqual(store.nextIndex(for: .sequential), 0)
    }

    func testSequentialNextOnEmptyReturnsNil() {
        XCTAssertNil(makeStore(count: 0).nextIndex(for: .sequential))
    }

    func testRandomNextReturnsNilWhenEmpty() {
        XCTAssertNil(makeStore(count: 0).nextIndex(for: .random))
    }

    func testRandomNextKeepsSingleTrack() {
        XCTAssertEqual(makeStore(count: 1).nextIndex(for: .random), 0)
    }

    func testRandomNextNeverRepeatsCurrent() {
        let store = makeStore(count: 5, current: 2)
        for _ in 0..<50 {
            let next = store.nextIndex(for: .random)
            XCTAssertNotNil(next)
            XCTAssertTrue((0..<5).contains(next!))
            XCTAssertNotEqual(next, 2)
        }
    }

    func testPreviousWrapsAround() {
        let store = makeStore(count: 3, current: 0)
        XCTAssertEqual(store.previousIndex(), 2)
        store.setCurrentIndex(1)
        XCTAssertEqual(store.previousIndex(), 0)
    }

    func testPreviousReturnsNilForSingleTrack() {
        XCTAssertNil(makeStore(count: 1).previousIndex())
        XCTAssertNil(makeStore(count: 0).previousIndex())
    }

    func testCurrentTrackFollowsIndex() {
        let store = makeStore(count: 2, current: 1)
        XCTAssertEqual(store.currentTrack?.title, "Title 1")
    }
}

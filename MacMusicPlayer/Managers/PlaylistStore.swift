//
//  PlaylistStore.swift
//  MacMusicPlayer
//
//  Created by X on 2024/09/23.
//

import Foundation

enum PlayMode: String {
    case sequential = "Sequential"
    case singleLoop = "Single Loop"
    case random = "Random"

    var localizedString: String {
        return NSLocalizedString(self.rawValue, comment: "")
    }
}

/// Owns authoritative track ordering (source of truth)
class PlaylistStore: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var currentIndex: Int = 0

    func setTracks(_ newTracks: [Track]) {
        tracks = newTracks
        currentIndex = 0
    }

    func setCurrentIndex(_ index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        currentIndex = index
    }

    func nextIndex(for playMode: PlayMode) -> Int? {
        switch playMode {
        case .sequential:
            let nextIndex = (currentIndex + 1) % tracks.count
            return nextIndex != currentIndex || tracks.count == 1 ? nextIndex : nil

        case .random:
            guard tracks.count > 1 else { return currentIndex }
            var randomIndex = Int.random(in: 0..<tracks.count)
            while randomIndex == currentIndex {
                randomIndex = Int.random(in: 0..<tracks.count)
            }
            return randomIndex

        case .singleLoop:
            return currentIndex
        }
    }

    func previousIndex() -> Int? {
        guard tracks.count > 1 else { return nil }
        return (currentIndex - 1 + tracks.count) % tracks.count
    }

    var isEmpty: Bool {
        tracks.isEmpty
    }

    var count: Int {
        tracks.count
    }

    var currentTrack: Track? {
        guard currentIndex < tracks.count else { return nil }
        return tracks[currentIndex]
    }
}

extension PlayMode {
    var tag: Int {
        switch self {
        case .sequential: return 0
        case .singleLoop: return 1
        case .random: return 2
        }
    }
}
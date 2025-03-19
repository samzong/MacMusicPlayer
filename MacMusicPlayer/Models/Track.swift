//
//  Track.swift
//  MacMusicPlayer
//
//  Created by X on 2024/09/18.
//

import SwiftUI

struct Track: Identifiable {
    let id: UUID
    let title: String
    let artist: String
    let url: URL
}

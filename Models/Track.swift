//
//  Track.swift
//  MacMusicPlayer
//
//  Created by X on 9/18/24.
//

import SwiftUI

struct Track: Identifiable {
    let id: UUID
    let title: String
    let artist: String
    let url: URL
}

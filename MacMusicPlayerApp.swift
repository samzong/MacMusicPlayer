//
//  MacMusicPlayerApp.swift
//  MacMusicPlayer
//
//  Created by X on 9/18/24.
//

import SwiftUI

@main
struct MacMusicPlayerApp: App {
    @StateObject private var playerManager = PlayerManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerManager)
        }
    }
}

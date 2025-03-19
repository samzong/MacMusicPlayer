//
//  MacMusicPlayerApp.swift
//  MacMusicPlayer
//
//  Created by X on 2024/09/18.
//

import SwiftUI

@main
struct MacMusicPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

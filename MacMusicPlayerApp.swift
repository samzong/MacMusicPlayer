//
//  MacMusicPlayerApp.swift
//  MacMusicPlayer
//
//  Created by X on 9/18/24.
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

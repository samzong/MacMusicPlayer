//
//  ContentView.swift
//  MacMusicPlayer
//
//  Created by X on 9/18/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var playerManager: PlayerManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(playerManager.currentTrack?.title ?? "No track selected")
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
            
            Text(playerManager.currentTrack?.artist ?? "Unknown Artist")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            HStack(spacing: 16) {
                Button(action: playerManager.playPrevious) {
                    Image(systemName: "backward.fill")
                }
                
                Button(action: {
                    if playerManager.isPlaying {
                        playerManager.pause()
                    } else {
                        playerManager.play()
                    }
                }) {
                    Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                }
                
                Button(action: playerManager.playNext) {
                    Image(systemName: "forward.fill")
                }
            }
            .padding(.top, 4)
        }
        .padding(8)
        .frame(width: 280)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(PlayerManager())
    }
}

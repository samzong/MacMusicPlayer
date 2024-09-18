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
        VStack {
            if let track = playerManager.currentTrack {
                Text(track.title)
                    .font(.title)
                Text(track.artist)
                    .font(.subheadline)
            } else {
                Text("No track selected")
                    .font(.title)
            }
            
            HStack {
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
                }
                
                Button(action: playerManager.playNext) {
                    Image(systemName: "forward.fill")
                }
            }
            .padding()
            .font(.largeTitle)
            
            Text("Playlist: \(playerManager.playlist.count) tracks")
                .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(PlayerManager())
    }
}

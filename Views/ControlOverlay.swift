//
//  ControlOverlay.swift
//  MacMusicPlayer
//
//  Created by X on 9/18/24.
//

import SwiftUI

struct ControlOverlay: View {
    @ObservedObject var playerManager: PlayerManager

    var body: some View {
        VStack {
            HStack {
                Button(action: playerManager.playPrevious) {
                    Image(systemName: "backward.fill")
                }
                .buttonStyle(.plain)

                Button(action: {
                    if playerManager.isPlaying {
                        playerManager.pause()
                    } else {
                        playerManager.play()
                    }
                }) {
                    Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.plain)

                Button(action: playerManager.playNext) {
                    Image(systemName: "forward.fill")
                }
                .buttonStyle(.plain)
            }
            .font(.largeTitle)
            .foregroundColor(.white)

            Spacer()

            // 这里可以添加其他控件，如进度条、音量控制等
        }
    }
}

// 预览提供者
struct ControlOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ControlOverlay(playerManager: PlayerManager())
            .background(Color.black.opacity(0.5))
    }
}

import SwiftUI
import AVKit // This import is important

struct VideoPlayerView: View {
    var videoURL: URL
    
    private var player: AVPlayer {
        return AVPlayer(url: videoURL)
    }
    
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player.play()
            }
    }
}

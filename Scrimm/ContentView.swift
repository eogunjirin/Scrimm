import SwiftUI
import AVKit
import WebKit

// --- HELPERS & VIEWMODELS ---
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(); view.blendingMode = .behindWindow; view.state = .active; view.material = .underWindowBackground
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

class PlayerWindowManager: NSObject, NSWindowDelegate {
    static let shared = PlayerWindowManager()
    private var playerWindow: NSWindow?
    private var playerManager: PlayerManager?
    
    private weak var playerModel: SharedPlayerModel?
    private weak var recentsManager: RecentsManager?

    func showPlayer(with video: FoundVideo, playerModel: SharedPlayerModel, recentsManager: RecentsManager) {
        self.playerModel = playerModel
        self.recentsManager = recentsManager
        playerModel.currentVideo = video
        
        if let playerWindow = playerWindow {
            playerWindow.makeKeyAndOrderFront(nil)
            playerWindow.title = video.pageTitle
            return
        }
        
        let playerView = PlayerView(onManagerCreated: { manager in
            self.playerManager = manager
        })
        .environmentObject(playerModel)
        .environmentObject(recentsManager)
        
        let hostingController = NSHostingController(rootView: playerView)
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = video.pageTitle
        newWindow.setContentSize(NSSize(width: 800, height: 450))
        newWindow.center()
        newWindow.delegate = self
        newWindow.tabbingMode = .disallowed
        
        self.playerWindow = newWindow
        newWindow.makeKeyAndOrderFront(nil)
    }
    
    func windowWillClose(_ notification: Notification) {
        if let manager = self.playerManager {
            let finalTime = manager.getCurrentTime()
            recentsManager?.updatePlaybackTime(for: manager.videoURL, at: finalTime)
        }
        self.playerWindow = nil
        self.playerManager = nil
    }
}

// --- MAIN CONTENT VIEW ---
struct ContentView: View {
    @State private var urlString: String = ""
    
    @EnvironmentObject private var playerModel: SharedPlayerModel
    @EnvironmentObject private var recentsManager: RecentsManager
    @EnvironmentObject private var navigationModel: NavigationModel

    var body: some View {
        ZStack {
            VisualEffectView().ignoresSafeArea()
            if let url = navigationModel.destinationURL {
                BrowserView(
                    url: url,
                    onBack: { navigationModel.reset() },
                    onVideoFound: { video in
                        PlayerWindowManager.shared.showPlayer(with: video, playerModel: playerModel, recentsManager: recentsManager)
                        recentsManager.addOrUpdate(video: video)
                    }
                )
            } else {
                LauncherView(
                    urlString: $urlString,
                    recentItems: $recentsManager.items,
                    onGo: { url in navigationModel.destinationURL = url },
                    onSelectRecent: { video in
                        PlayerWindowManager.shared.showPlayer(with: video, playerModel: playerModel, recentsManager: recentsManager)
                        recentsManager.addOrUpdate(video: video)
                    },
                    onDeleteRecent: { item in
                        recentsManager.delete(item: item)
                    },
                    onClearRecents: {
                        recentsManager.clearAll()
                    })
            }
        }
        .frame(minWidth: 1024, minHeight: 768)
        .preferredColorScheme(.dark)
    }
}

// --- ALL MODULAR VIEWS ---

struct LauncherView: View {
    @Binding var urlString: String; @Binding var recentItems: [RecentItem]
    var onGo: (URL) -> Void; var onSelectRecent: (FoundVideo) -> Void
    var onDeleteRecent: (RecentItem) -> Void; var onClearRecents: () -> Void
    
    private func formatTime(_ totalSeconds: Double) -> String {
        let secondsInt = Int(totalSeconds); let hours = secondsInt / 3600; let minutes = (secondsInt % 3600) / 60; let seconds = (secondsInt % 3600) % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        else { return String(format: "%02d:%02d", minutes, seconds) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("Enter URL", text: $urlString).textFieldStyle(PlainTextFieldStyle()).font(.system(size: 14)).padding(12).background(Color.black.opacity(0.2)).cornerRadius(8).foregroundColor(.white)
                Button("Go") {
                    let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines); guard !trimmed.isEmpty else { return }
                    var finalUrl = trimmed
                    if !finalUrl.lowercased().hasPrefix("http") { finalUrl = "https://" + finalUrl }
                    if let url = URL(string: finalUrl), url.host != nil { onGo(url) }
                }.keyboardShortcut(.defaultAction).font(.system(size: 14, weight: .semibold)).padding(.horizontal, 22).padding(.vertical, 12).background(Color.accentColor).foregroundColor(.white).cornerRadius(8).buttonStyle(PlainButtonStyle())
            }.frame(maxWidth: 500).padding(.top, 40).padding(.horizontal)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Recents").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary); Spacer()
                    if !recentItems.isEmpty { Button("Clear All", action: onClearRecents).font(.system(size: 12)) }
                }.padding(.horizontal, 5)
                
                if recentItems.isEmpty {
                    Text("Recent videos will be added here.").font(.system(size: 13)).foregroundColor(.secondary).padding().frame(maxWidth: .infinity).background(Color.white.opacity(0.05)).cornerRadius(8)
                } else {
                    ForEach(recentItems) { item in
                        HStack {
                            Button(action: { if let url = URL(string: item.urlString) { onSelectRecent(FoundVideo(pageTitle: item.title, videoURL: url, lastPlayedTime: item.playbackTime)) } }) {
                                HStack { Image(systemName: "clock.arrow.circlepath"); Text(item.title).lineLimit(1); Spacer(); Text(formatTime(item.playbackTime)).foregroundColor(.secondary) }
                            }.buttonStyle(PlainButtonStyle())
                            Button(action: { onDeleteRecent(item) }) { Image(systemName: "xmark.circle.fill").foregroundColor(.gray.opacity(0.7)) }.buttonStyle(PlainButtonStyle())
                        }.padding(.horizontal, 12).padding(.vertical, 10).background(Color.white.opacity(0.12)).cornerRadius(8)
                    }
                }
            }.frame(maxWidth: 500).padding(.top, 25)
            Spacer()
        }
    }
}

struct BrowserView: View {
    let url: URL; var onBack: () -> Void; var onVideoFound: (FoundVideo) -> Void
    var body: some View {
        ZStack(alignment: .topLeading) {
            WebView(url: url, onVideoFound: onVideoFound)
            BackButton(action: onBack)
        }
    }
}

class PlayerManager: ObservableObject {
    let player: AVPlayer; let videoURL: URL
    private var activity: NSObjectProtocol?
    init(video: FoundVideo) {
        self.player = AVPlayer(url: video.videoURL); self.videoURL = video.videoURL
        player.seek(to: CMTime(seconds: video.lastPlayedTime, preferredTimescale: 600))
        self.activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleDisplaySleepDisabled], reason: "Playing video")
    }
    func play() { player.play() }
    func cleanup() {
        player.pause()
        if let activity = self.activity { ProcessInfo.processInfo.endActivity(activity); self.activity = nil }
    }
    func getCurrentTime() -> Double { CMTimeGetSeconds(player.currentTime()) }
    deinit { cleanup() }
}

struct PlayerView: View {
    @EnvironmentObject private var playerModel: SharedPlayerModel
    var onManagerCreated: (PlayerManager) -> Void

    var body: some View {
        if let video = playerModel.currentVideo {
            PlayerContentView(video: video, onManagerCreated: onManagerCreated)
                .id(video.id)
        } else {
            Text("No video selected.").frame(minWidth: 400, minHeight: 225)
        }
    }
}

struct PlayerContentView: View {
    let video: FoundVideo
    var onManagerCreated: (PlayerManager) -> Void
    @StateObject private var playerManager: PlayerManager
    
    init(video: FoundVideo, onManagerCreated: @escaping (PlayerManager) -> Void) {
        self.video = video
        self.onManagerCreated = onManagerCreated
        self._playerManager = StateObject(wrappedValue: PlayerManager(video: video))
    }
    
    var body: some View {
        VideoPlayer(player: playerManager.player)
            .onAppear {
                playerManager.play()
                onManagerCreated(playerManager)
            }
            .edgesIgnoringSafeArea(.all)
    }
}

struct BackButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward.circle.fill").font(.title).foregroundColor(.white.opacity(0.7)).shadow(radius: 5)
        }.buttonStyle(PlainButtonStyle()).padding(.leading).padding(.top, 12)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SharedPlayerModel())
            .environmentObject(RecentsManager())
            .environmentObject(NavigationModel())
    }
}

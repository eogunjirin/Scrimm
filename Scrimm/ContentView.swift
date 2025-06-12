import SwiftUI
import AVKit

// --- DATA MODELS & HELPERS (Unchanged) ---
struct RecentItem: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let urlString: String
    var playbackTime: Double

    init(title: String, url: URL, playbackTime: Double = 0.0) {
        self.id = UUID()
        self.title = title
        self.urlString = url.absoluteString
        self.playbackTime = playbackTime
    }
}

struct FoundVideo: Identifiable, Equatable {
    static func == (lhs: FoundVideo, rhs: FoundVideo) -> Bool { lhs.id == rhs.id }
    let id = UUID()
    let pageTitle: String
    let videoURL: URL
    let lastPlayedTime: Double
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow; view.state = .active; view.material = .underWindowBackground
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// --- MAIN CONTENT VIEW ---
struct ContentView: View {
    enum AppState { case launcher, browser, videoPlayer }
    
    @State private var appState: AppState = .launcher
    @State private var urlString: String = ""
    @State private var destinationURL: URL?
    @State private var foundVideo: FoundVideo?
    @State private var recentItems: [RecentItem] = []
    private let recentsKey = "VideoRecents"

    var body: some View {
        ZStack {
            VisualEffectView().ignoresSafeArea()

            switch appState {
            case .launcher:
                LauncherView(
                    urlString: $urlString,
                    recentItems: $recentItems,
                    onGo: { url in
                        self.destinationURL = url
                        self.appState = .browser
                    },
                    onSelectRecent: { video in
                        self.foundVideo = video
                        self.appState = .videoPlayer
                    },
                    onClearRecents: clearRecents
                )
            case .browser:
                if let url = destinationURL {
                    BrowserView(
                        url: url,
                        onBack: { self.appState = .launcher },
                        onVideoFound: { videoFromWeb in
                            self.foundVideo = FoundVideo(
                                pageTitle: videoFromWeb.pageTitle,
                                videoURL: videoFromWeb.videoURL,
                                lastPlayedTime: 0.0
                            )
                            self.appState = .videoPlayer
                        }
                    )
                }
            case .videoPlayer:
                if let video = foundVideo {
                    PlayerView(
                        video: video,
                        onBack: { finalTime in
                            self.updateRecentItemTime(for: video, at: finalTime)
                            self.appState = .launcher
                        }
                    )
                }
            }
        }
        .frame(minWidth: 700, minHeight: 450)
        .preferredColorScheme(.dark)
        .onAppear(perform: loadRecents)
        .onChange(of: foundVideo) { newVideo in
            if let video = newVideo {
                addRecentItem(title: video.pageTitle, url: video.videoURL)
            }
        }
    }
    
    // --- HELPER FUNCTIONS (addRecentItem is updated) ---
    private func addRecentItem(title: String, url: URL) {
        if !recentItems.contains(where: { $0.urlString == url.absoluteString }) {
            recentItems.insert(RecentItem(title: title, url: url), at: 0)
            
            // ** THIS IS THE CHANGE: Limit is now 10 **
            if recentItems.count > 10 {
                recentItems = Array(recentItems.prefix(10))
            }
            saveRecents()
        }
    }

    private func updateRecentItemTime(for video: FoundVideo, at time: Double) {
        if let index = recentItems.firstIndex(where: { $0.urlString == video.videoURL.absoluteString }) {
            recentItems[index].playbackTime = time
            saveRecents()
        }
    }
    
    private func saveRecents() {
        if let encoded = try? JSONEncoder().encode(recentItems) { UserDefaults.standard.set(encoded, forKey: recentsKey) }
    }

    private func loadRecents() {
        if let data = UserDefaults.standard.data(forKey: recentsKey),
           let decoded = try? JSONDecoder().decode([RecentItem].self, from: data) { self.recentItems = decoded }
    }

    private func clearRecents() {
        recentItems.removeAll()
        saveRecents()
    }
}

// --- UI COMPONENTS, EXTENSIONS, & PREVIEWS (Unchanged) ---

struct LauncherView: View {
    @Binding var urlString: String
    @Binding var recentItems: [RecentItem]
    var onGo: (URL) -> Void
    var onSelectRecent: (FoundVideo) -> Void
    var onClearRecents: () -> Void

    private func formatTime(_ totalSeconds: Double) -> String {
        let seconds = Int(totalSeconds) % 60
        let minutes = Int(totalSeconds) / 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("Enter URL", text: $urlString)
                    .textFieldStyle(PlainTextFieldStyle()).font(.system(size: 14)).padding(12)
                    .background(Color.black.opacity(0.2)).cornerRadius(8).foregroundColor(.white)
                Button("Go") {
                    let trimmedString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedString.isEmpty else { return }
                    var finalUrlString = trimmedString
                    if !trimmedString.lowercased().hasPrefix("http://") && !trimmedString.lowercased().hasPrefix("https://") {
                        finalUrlString = "https://" + trimmedString
                    }
                    if let url = URL(string: finalUrlString), url.host != nil { onGo(url) }
                }.keyboardShortcut(.defaultAction).font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 22).padding(.vertical, 12).background(Color.accentColor)
                .foregroundColor(.white).cornerRadius(8).buttonStyle(PlainButtonStyle())
            }.frame(maxWidth: 500).padding(.top, 40).padding(.horizontal)
            
            if !recentItems.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("Recents").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary)
                        Spacer()
                        Button("Clear All", action: onClearRecents)
                            .font(.system(size: 12)).foregroundColor(.accentColor).buttonStyle(PlainButtonStyle())
                    }.padding(.horizontal, 5)

                    ForEach(recentItems) { item in
                        Button(action: {
                            if let url = URL(string: item.urlString) {
                                onSelectRecent(FoundVideo(
                                    pageTitle: item.title,
                                    videoURL: url,
                                    lastPlayedTime: item.playbackTime
                                ))
                            }
                        }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text(item.title).lineLimit(1)
                                Spacer()
                                Text(formatTime(item.playbackTime)).foregroundColor(.secondary)
                            }.padding(.horizontal, 12).padding(.vertical, 10)
                        }.buttonStyle(PlainButtonStyle()).background(Color.white.opacity(0.12)).cornerRadius(8)
                    }
                }.frame(maxWidth: 500).padding(.top, 25)
            }
            Spacer()
        }
    }
}

struct PlayerView: View {
    let video: FoundVideo
    var onBack: (Double) -> Void
    @State private var player: AVPlayer
    
    init(video: FoundVideo, onBack: @escaping (Double) -> Void) {
        self.video = video
        self.onBack = onBack
        self._player = State(initialValue: AVPlayer(url: video.videoURL))
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VideoPlayer(player: player)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    let seekTime = CMTime(seconds: video.lastPlayedTime, preferredTimescale: 600)
                    player.seek(to: seekTime)
                    player.play()
                }
                .onDisappear {
                    let currentTime = CMTimeGetSeconds(player.currentTime())
                    onBack(currentTime)
                }

            BackButton(action: {
                let currentTime = CMTimeGetSeconds(player.currentTime())
                onBack(currentTime)
            })
        }
    }
}

struct BrowserView: View {
    let url: URL
    var onBack: () -> Void
    var onVideoFound: (FoundVideo) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            WebView(url: url) { video in
                let newVideo = FoundVideo(pageTitle: video.pageTitle, videoURL: video.videoURL, lastPlayedTime: 0)
                onVideoFound(newVideo)
            }
            BackButton(action: onBack)
        }
    }
}

struct BackButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward.circle.fill")
                .font(.title).foregroundColor(.white.opacity(0.7)).shadow(radius: 5)
        }.buttonStyle(PlainButtonStyle()).padding(.leading).padding(.top, 12)
    }
}

extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

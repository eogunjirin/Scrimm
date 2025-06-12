import SwiftUI

// --- DATA MODELS & HELPERS ---
struct RecentItem: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let urlString: String
    init(title: String, url: URL) { self.id = UUID(); self.title = title; self.urlString = url.absoluteString }
}

struct FoundVideo: Identifiable, Equatable {
    static func == (lhs: FoundVideo, rhs: FoundVideo) -> Bool { lhs.id == rhs.id }
    let id = UUID()
    let pageTitle: String
    let videoURL: URL
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
    
    enum AppState {
        case launcher, browser, videoPlayer
    }
    
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
                        onVideoFound: { video in
                            self.foundVideo = video
                            self.appState = .videoPlayer
                        }
                    )
                }
            case .videoPlayer:
                if let video = foundVideo {
                    PlayerView(
                        video: video,
                        onBack: { self.appState = .launcher }
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
    
    // --- Helper Functions ---
    private func addRecentItem(title: String, url: URL) {
        let newItem = RecentItem(title: title, url: url)
        recentItems.removeAll { $0.urlString == newItem.urlString }
        recentItems.insert(newItem, at: 0)
        if recentItems.count > 5 { recentItems = Array(recentItems.prefix(5)) }
        saveRecents()
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
        UserDefaults.standard.removeObject(forKey: recentsKey)
    }
}

// --- MODULAR UI COMPONENTS ---

struct LauncherView: View {
    @Binding var urlString: String
    @Binding var recentItems: [RecentItem]
    var onGo: (URL) -> Void
    var onSelectRecent: (FoundVideo) -> Void
    var onClearRecents: () -> Void

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
                                onSelectRecent(FoundVideo(pageTitle: item.title, videoURL: url))
                            }
                        }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text(item.title).lineLimit(1)
                                Spacer()
                                Text("00:09").foregroundColor(.secondary)
                            }.padding(.horizontal, 12).padding(.vertical, 10)
                        }.buttonStyle(PlainButtonStyle()).background(Color.white.opacity(0.12)).cornerRadius(8)
                    }
                }.frame(maxWidth: 500).padding(.top, 25)
            }
            Spacer()
        }
    }
}

struct BrowserView: View {
    let url: URL
    var onBack: () -> Void
    var onVideoFound: (FoundVideo) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            WebView(url: url, onVideoFound: onVideoFound)
            BackButton(action: onBack)
        }
    }
}

struct PlayerView: View {
    let video: FoundVideo
    var onBack: () -> Void
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VideoPlayerView(videoURL: video.videoURL)
            BackButton(action: onBack)
        }
    }
}

struct BackButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward.circle.fill")
                .font(.title)
                .foregroundColor(.white.opacity(0.7))
                .shadow(radius: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.leading)
        .padding(.top, 12)
    }
}

// --- EXTENSIONS & PREVIEWS ---
extension URL: Identifiable {
    public var id: String { self.absoluteString }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

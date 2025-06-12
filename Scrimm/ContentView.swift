import SwiftUI

// --- DATA MODEL FOR RECENTS ---
struct RecentItem: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let urlString: String
    init(title: String, url: URL) {
        self.id = UUID()
        self.title = title
        self.urlString = url.absoluteString
    }
}

// --- STRUCT TO BUNDLE FOUND VIDEO INFO ---
struct FoundVideo: Identifiable, Equatable {
    static func == (lhs: FoundVideo, rhs: FoundVideo) -> Bool {
        return lhs.id == rhs.id
    }
    let id = UUID()
    let pageTitle: String
    let videoURL: URL
}

// --- HELPER VIEW FOR TRANSLUCENT BACKGROUND ---
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .underWindowBackground
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// --- MAIN CONTENT VIEW ---
struct ContentView: View {
    @State private var urlString: String = ""
    @State private var destinationURL: URL?
    @State private var foundVideo: FoundVideo? // This is now the trigger for the video sheet
    @State private var recentItems: [RecentItem] = []
    private let recentsKey = "VideoRecents"

    var body: some View {
        ZStack {
            VisualEffectView().ignoresSafeArea()

            VStack(spacing: 0) {
                // ... (URL Input Section - no changes)
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
                        if let url = URL(string: finalUrlString), url.host != nil { destinationURL = url }
                    }.keyboardShortcut(.defaultAction).font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 22).padding(.vertical, 12).background(Color.accentColor)
                    .foregroundColor(.white).cornerRadius(8).buttonStyle(PlainButtonStyle())
                }.frame(maxWidth: 500).padding(.top, 40).padding(.horizontal)
                
                // Recents List Section
                if !recentItems.isEmpty {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Recents").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                            Spacer()
                            Button("Clear All", action: clearRecents)
                                .font(.system(size: 12)).foregroundColor(.accentColor).buttonStyle(PlainButtonStyle())
                        }.padding(.horizontal, 5)

                        ForEach(recentItems) { item in
                            Button(action: {
                                if let url = URL(string: item.urlString) {
                                    self.foundVideo = FoundVideo(pageTitle: item.title, videoURL: url)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        // This sheet now correctly receives a FoundVideo object from the updated WebView
        .sheet(item: $destinationURL) { url in
            WebView(url: url) { video in
                self.foundVideo = video
                self.destinationURL = nil
            }
            .frame(minWidth: 800, idealWidth: 1280, minHeight: 600, idealHeight: 720)
        }
        .sheet(item: $foundVideo) { video in
            VideoPlayerView(videoURL: video.videoURL)
                .frame(minWidth: 800, minHeight: 450)
        }
        .onAppear(perform: loadRecents)
        .onChange(of: foundVideo) { newVideo in
            if let video = newVideo {
                addRecentItem(title: video.pageTitle, url: video.videoURL)
            }
        }
    }

    private func addRecentItem(title: String, url: URL) {
        let newItem = RecentItem(title: title, url: url)
        recentItems.removeAll { $0.urlString == newItem.urlString }
        recentItems.insert(newItem, at: 0)
        if recentItems.count > 5 { recentItems = Array(recentItems.prefix(5)) }
        saveRecents()
    }
    private func saveRecents() {
        if let encoded = try? JSONEncoder().encode(recentItems) {
            UserDefaults.standard.set(encoded, forKey: recentsKey)
        }
    }
    private func loadRecents() {
        if let data = UserDefaults.standard.data(forKey: recentsKey),
           let decoded = try? JSONDecoder().decode([RecentItem].self, from: data) {
            self.recentItems = decoded
        }
    }
    private func clearRecents() {
        recentItems.removeAll()
        UserDefaults.standard.removeObject(forKey: recentsKey)
    }
}

// --- URL EXTENSION ---
extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

// --- PREVIEW PROVIDER ---
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

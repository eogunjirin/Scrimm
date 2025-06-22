import SwiftUI
import AVKit
import WebKit

// --- HELPERS & VIEWMODELS ---

/// A SwiftUI wrapper for `NSVisualEffectView` to create the "frosted glass" background effect.
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

/// A singleton class that manually manages the lifecycle of the detached player window.
/// This provides absolute control over its creation, presentation, and state-saving,
/// guaranteeing only one player window ever exists and preventing state-related bugs.
class PlayerWindowManager: NSObject, NSWindowDelegate {
    static let shared = PlayerWindowManager()
    private var playerWindow: NSWindow?
    private var playerManager: PlayerManager?
    
    // Use weak references to environment objects to prevent retain cycles.
    private weak var playerModel: SharedPlayerModel?
    private weak var recentsManager: RecentsManager?

    /// The single entry point for showing the player.
    /// It either creates a new window or brings the existing one to the front.
    func showPlayer(with video: FoundVideo, playerModel: SharedPlayerModel, recentsManager: RecentsManager) {
        self.playerModel = playerModel
        self.recentsManager = recentsManager
        
        // Update the shared model, which the PlayerView observes.
        playerModel.currentVideo = video
        
        // If the window already exists, update its title and bring it to the front.
        if let playerWindow = playerWindow {
            playerWindow.makeKeyAndOrderFront(nil)
            playerWindow.title = video.pageTitle
            return
        }
        
        // If no window exists, create and configure a new one.
        let playerView = PlayerView(onManagerCreated: { manager in
            // This closure creates the bridge, allowing us to get the manager instance.
            self.playerManager = manager
        })
        .environmentObject(playerModel)
        .environmentObject(recentsManager)
        
        let hostingController = NSHostingController(rootView: playerView)
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = video.pageTitle
        newWindow.setContentSize(NSSize(width: 800, height: 450))
        newWindow.center()
        newWindow.delegate = self // Set self as delegate to handle the close event.
        newWindow.tabbingMode = .disallowed // Explicitly remove tab bar menu items.
        
        self.playerWindow = newWindow
        newWindow.makeKeyAndOrderFront(nil)
    }
    
    /// A guaranteed OS-level callback that fires just before the window closes.
    /// This is the most reliable place to save the final video playback time.
    func windowWillClose(_ notification: Notification) {
        if let manager = self.playerManager {
            let finalTime = manager.getCurrentTime()
            recentsManager?.updatePlaybackTime(for: manager.videoURL, at: finalTime)
        }
        // Nil out references to allow the window and manager to be deallocated.
        self.playerWindow = nil
        self.playerManager = nil
    }
}

// --- MAIN CONTENT VIEW ---

/// The root view for the main application window. It acts as a router,
/// displaying either the launcher or the browser based on the navigation state.
struct ContentView: View {
    // Environment objects are the "single source of truth" injected by ScrimmApp.
    @EnvironmentObject private var playerModel: SharedPlayerModel
    @EnvironmentObject private var recentsManager: RecentsManager
    @EnvironmentObject private var navigationModel: NavigationModel

    var body: some View {
        ZStack {
            VisualEffectView().ignoresSafeArea()
            
            // The view's content is driven by the shared navigation model.
            if let url = navigationModel.destinationURL {
                // If a URL is set, show the browser.
                BrowserView(
                    url: url,
                    onBack: { navigationModel.reset() }, // Resetting the model returns to the launcher.
                    onVideoFound: { video in
                        // Use the window manager to show the player.
                        PlayerWindowManager.shared.showPlayer(with: video, playerModel: playerModel, recentsManager: recentsManager)
                        recentsManager.addOrUpdate(video: video)
                    })
            } else {
                // Otherwise, show the launcher.
                LauncherView()
            }
        }
        .frame(minWidth: 1024, minHeight: 768)
        .preferredColorScheme(.dark)
    }
}

// --- ALL MODULAR VIEWS ---

/// The initial view of the application, containing the search bar and recents list.
struct LauncherView: View {
    // This view now gets the managers it needs directly from the environment.
    @EnvironmentObject private var navigationModel: NavigationModel
    @EnvironmentObject private var recentsManager: RecentsManager
    @EnvironmentObject private var providerManager: ProviderManager
    @EnvironmentObject private var playerModel: SharedPlayerModel

    // Local state for the search functionality.
    @State private var searchQuery: String = ""
    @State private var selectedProvider: Provider?

    /// Formats time in seconds to a "HH:mm:ss" or "mm:ss" string.
    private func formatTime(_ totalSeconds: Double) -> String {
        let secondsInt = Int(totalSeconds); let hours = secondsInt / 3600; let minutes = (secondsInt % 3600) / 60; let seconds = (secondsInt % 3600) % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        else { return String(format: "%02d:%02d", minutes, seconds) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // The Search Bar
            HStack(spacing: 0) {
                Picker("", selection: $selectedProvider) {
                    ForEach(providerManager.providers) { provider in
                        Text(provider.name).tag(provider as Provider?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 90)
                .padding(.leading, 4)

                TextField("Search for a video...", text: $searchQuery)
                    .textFieldStyle(PlainTextFieldStyle()).font(.system(size: 14)).padding(.horizontal, 12)
                
                Button(action: performSearch) { Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .semibold)) }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).padding(.trailing, 8)
            }
            .padding(.horizontal, 8)
            .frame(height: 44).background(Color.black.opacity(0.25)).cornerRadius(8)
            .frame(maxWidth: 550).padding(.top, 40)
            
            // The Recents Section
            VStack(spacing: 8) {
                HStack {
                    Text("Recents").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary); Spacer()
                    if !recentsManager.items.isEmpty { Button("Clear All", action: { recentsManager.clearAll() }).font(.system(size: 12)) }
                }.padding(.horizontal, 5)
                
                if recentsManager.items.isEmpty {
                    Text("Recent videos will be added here.").font(.system(size: 13)).foregroundColor(.secondary).padding().frame(maxWidth: .infinity).background(Color.white.opacity(0.05)).cornerRadius(8)
                } else {
                    ForEach(recentsManager.items) { item in
                        HStack {
                            Button(action: {
                                if let url = URL(string: item.urlString) {
                                    let video = FoundVideo(pageTitle: item.title, videoURL: url, lastPlayedTime: item.playbackTime)
                                    PlayerWindowManager.shared.showPlayer(with: video, playerModel: playerModel, recentsManager: recentsManager)
                                    recentsManager.addOrUpdate(video: video)
                                }
                            }) {
                                HStack { Image(systemName: "clock.arrow.circlepath"); Text(item.title).lineLimit(1); Spacer(); Text(formatTime(item.playbackTime)).foregroundColor(.secondary) }
                            }.buttonStyle(PlainButtonStyle())
                            Button(action: { recentsManager.delete(item: item) }) { Image(systemName: "xmark.circle.fill").foregroundColor(.gray.opacity(0.7)) }.buttonStyle(PlainButtonStyle())
                        }.padding(.horizontal, 12).padding(.vertical, 10).background(Color.white.opacity(0.12)).cornerRadius(8)
                    }
                }
            }.frame(maxWidth: 550).padding(.top, 25)
            Spacer()
        }
        .onAppear {
            if selectedProvider == nil {
                selectedProvider = providerManager.providers.first
            }
        }
    }
    
    /// Constructs the final search URL and passes it to the navigation model to trigger browsing.
    private func performSearch() {
        guard let provider = selectedProvider,
              !searchQuery.isEmpty,
              let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
              let url = URL(string: provider.searchUrl + encodedQuery) else { return }
        navigationModel.destinationURL = url
    }
}

/// A container view for the `WebView` that also includes a back button.
struct BrowserView: View {
    let url: URL; var onBack: () -> Void; var onVideoFound: (FoundVideo) -> Void
    @State private var webViewInstance = WKWebView()

    var body: some View {
        ZStack(alignment: .topLeading) {
            WebView(url: url, webView: webViewInstance, onVideoFound: onVideoFound)
                .onDisappear {
                    // This is the guaranteed fix for the audio leak. When the browser view
                    // is removed from the hierarchy, it forces the WKWebView to stop all activity.
                    webViewInstance.stopLoading()
                    webViewInstance.load(URLRequest(url: URL(string:"about:blank")!))
                }
            BackButton(action: onBack)
        }
    }
}

/// A robust class to manage the AVPlayer instance and system-level interactions like power management.
class PlayerManager: ObservableObject {
    let player: AVPlayer; let videoURL: URL; private var activity: NSObjectProtocol?
    init(video: FoundVideo) {
        self.player = AVPlayer(url: video.videoURL); self.videoURL = video.videoURL
        player.seek(to: CMTime(seconds: video.lastPlayedTime, preferredTimescale: 600))
        // Acquire a power assertion to prevent the display and system from sleeping.
        self.activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleDisplaySleepDisabled], reason: "Playing video")
    }
    func play() { player.play() }
    func cleanup() { player.pause(); if let activity = self.activity { ProcessInfo.processInfo.endActivity(activity); self.activity = nil } }
    func getCurrentTime() -> Double { CMTimeGetSeconds(player.currentTime()) }
    deinit { cleanup() } // The deinitializer guarantees the power assertion is always released.
}

/// The root view for the player window. It observes the shared model for changes.
struct PlayerView: View {
    @EnvironmentObject private var playerModel: SharedPlayerModel
    var onManagerCreated: (PlayerManager) -> Void

    var body: some View {
        if let video = playerModel.currentVideo {
            // The .id() modifier is critical. It forces SwiftUI to destroy the old
            // PlayerContentView and create a brand new one whenever the video ID changes.
            PlayerContentView(video: video, onManagerCreated: onManagerCreated).id(video.id)
        } else {
            Text("No video selected.").frame(minWidth: 400, minHeight: 225)
        }
    }
}

/// A helper view that directly contains the VideoPlayer and its manager.
/// This allows us to cleanly manage the lifecycle with .onAppear and .id.
struct PlayerContentView: View {
    let video: FoundVideo; var onManagerCreated: (PlayerManager) -> Void
    @StateObject private var playerManager: PlayerManager
    init(video: FoundVideo, onManagerCreated: @escaping (PlayerManager) -> Void) {
        self.video = video; self.onManagerCreated = onManagerCreated
        self._playerManager = StateObject(wrappedValue: PlayerManager(video: video))
    }
    var body: some View {
        VideoPlayer(player: playerManager.player)
            .onAppear {
                playerManager.play()
                // Pass the manager instance up to the window manager for state saving on close.
                onManagerCreated(playerManager)
            }
            .edgesIgnoringSafeArea(.all)
    }
}

/// A simple, reusable back button.
struct BackButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward.circle.fill").font(.title).foregroundColor(.white.opacity(0.7)).shadow(radius: 5)
        }.buttonStyle(PlainButtonStyle()).padding(.leading).padding(.top, 12)
    }
}

// Preview provider for designing views in Xcode.
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SharedPlayerModel())
            .environmentObject(RecentsManager())
            .environmentObject(NavigationModel())
            .environmentObject(ProviderManager())
    }
}

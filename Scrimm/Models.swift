import Foundation
import SwiftUI
import AVKit

// --- SHARED APPLICATION STATE ---

/// A shared, observable object that acts as the single source of truth for the currently active video.
/// This allows the main window (browser) and the player window to communicate state changes reliably.
class SharedPlayerModel: ObservableObject {
    /// The video that should be displayed in the player window. Any SwiftUI view observing this
    /// property will automatically update when it changes.
    @Published var currentVideo: FoundVideo?
}

/// A shared, observable object that manages the main window's navigation state.
/// This prevents stale state when the app is relaunched from the dock.
class NavigationModel: ObservableObject {
    /// The URL the browser should be displaying. If `nil`, the app shows the launcher.
    @Published var destinationURL: URL?
    /// The current text in the search bar.
    @Published var urlString: String = ""
    
    /// Atomically resets the navigation state, forcing the UI to return to the launcher.
    /// This is called by the AppDelegate when the app is reopened from the dock.
    func reset() {
        DispatchQueue.main.async {
            self.destinationURL = nil
            self.urlString = ""
        }
    }
}

// --- DATA MANAGERS ---

/// A shared, observable object that manages the creation and persistence of the "Recents" list.
/// By centralizing this logic, we ensure that UI updates are instantaneous and data handling is consistent.
class RecentsManager: ObservableObject {
    /// The array of recent items, published to the UI.
    @Published var items: [RecentItem] = []
    private let recentsKey = "VideoRecents"

    init() {
        self.items = PersistenceController.shared.loadRecents()
    }

    /// The definitive method for adding a new video to the list or updating its position.
    func addOrUpdate(video: FoundVideo) {
        // Find if an item for this video already exists to preserve its playback time.
        let existingTime = items.first(where: { $0.urlString == video.videoURL.absoluteString })?.playbackTime ?? video.lastPlayedTime
        // Atomically remove the old item and insert the new/updated item at the top.
        items.removeAll { $0.urlString == video.videoURL.absoluteString }
        let newItem = RecentItem(title: video.pageTitle, url: video.videoURL, playbackTime: existingTime)
        items.insert(newItem, at: 0)
        // Enforce the list limit.
        if items.count > 10 {
            items = Array(items.prefix(10))
        }
        saveRecents()
    }
    
    /// Updates the stored playback time for a specific video URL.
    func updatePlaybackTime(for url: URL, at time: Double) {
        if let index = items.firstIndex(where: { $0.urlString == url.absoluteString }) {
            items[index].playbackTime = time
            saveRecents()
        }
    }
    
    /// Deletes a single item from the list.
    func delete(item: RecentItem) {
        items.removeAll { $0.id == item.id }
        saveRecents()
    }
    
    /// Deletes all items from the list.
    func clearAll() {
        items.removeAll()
        saveRecents()
    }
    
    private func saveRecents() {
        PersistenceController.shared.saveRecents(self.items)
    }
}

/// A shared, observable object responsible for loading the list of search providers from the bundled JSON file.
class ProviderManager: ObservableObject {
    @Published var providers: [Provider] = []

    init() {
        loadProviders()
    }

    private func loadProviders() {
        guard let url = Bundle.main.url(forResource: "providers", withExtension: "json") else {
            print("CRITICAL ERROR: providers.json not found in bundle.")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            self.providers = try JSONDecoder().decode([Provider].self, from: data)
        } catch {
            print("Error decoding providers.json: \(error)")
        }
    }
}


// --- PERSISTENCE ---

/// A simple singleton to handle the low-level logic of saving and loading data to `UserDefaults`.
class PersistenceController {
    static let shared = PersistenceController()
    private let recentsKey = "VideoRecents"
    func saveRecents(_ recents: [RecentItem]) {
        if let encoded = try? JSONEncoder().encode(recents) { UserDefaults.standard.set(encoded, forKey: recentsKey) }
    }
    func loadRecents() -> [RecentItem] {
        if let data = UserDefaults.standard.data(forKey: recentsKey),
           let decoded = try? JSONDecoder().decode([RecentItem].self, from: data) { return decoded }
        return []
    }
}

// --- DATA STRUCTURES ---

struct RecentItem: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let urlString: String
    var playbackTime: Double
    init(title: String, url: URL, playbackTime: Double = 0.0) {
        self.id = UUID(); self.title = title; self.urlString = url.absoluteString; self.playbackTime = playbackTime
    }
}

struct FoundVideo: Identifiable, Codable, Equatable, Hashable {
    let id = UUID()
    let pageTitle: String
    let videoURL: URL
    let lastPlayedTime: Double
}

/// A type-safe representation of a search provider, decoded from `providers.json`.
struct Provider: Codable, Identifiable, Hashable {
    let id = UUID()
    let name: String
    let searchUrl: String

    private enum CodingKeys: String, CodingKey {
        case name, searchUrl
    }
}

extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

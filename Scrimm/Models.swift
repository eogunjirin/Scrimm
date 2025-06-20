import Foundation
import SwiftUI
import AVKit

// --- SHARED DATA MODELS ---
class SharedPlayerModel: ObservableObject {
    @Published var currentVideo: FoundVideo?
}

class NavigationModel: ObservableObject {
    @Published var destinationURL: URL?
    
    func reset() {
        destinationURL = nil
    }
}

// --- RECENTS DATA MANAGER ---
class RecentsManager: ObservableObject {
    @Published var items: [RecentItem] = []
    private let recentsKey = "VideoRecents"

    init() { self.items = PersistenceController.shared.loadRecents() }

    func addOrUpdate(video: FoundVideo) {
        items.removeAll { $0.urlString == video.videoURL.absoluteString }
        let newItem = RecentItem(title: video.pageTitle, url: video.videoURL, playbackTime: video.lastPlayedTime)
        items.insert(newItem, at: 0)
        if items.count > 10 { items = Array(items.prefix(10)) }
        saveRecents()
    }
    
    func updatePlaybackTime(for url: URL, at time: Double) {
        if let index = items.firstIndex(where: { $0.urlString == url.absoluteString }) {
            items[index].playbackTime = time
            saveRecents()
        }
    }
    
    func delete(item: RecentItem) { items.removeAll { $0.id == item.id }; saveRecents() }
    func clearAll() { items.removeAll(); saveRecents() }
    
    // ** THIS IS THE FIX: The saveRecents call is now correct. **
    private func saveRecents() { PersistenceController.shared.saveRecents(self.items) }
}

// Simple singleton to handle saving and loading data.
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
    let id: UUID; let title: String; let urlString: String; var playbackTime: Double
    init(title: String, url: URL, playbackTime: Double = 0.0) {
        self.id = UUID(); self.title = title; self.urlString = url.absoluteString; self.playbackTime = playbackTime
    }
}
struct FoundVideo: Identifiable, Codable, Equatable, Hashable {
    let id = UUID(); let pageTitle: String; let videoURL: URL; let lastPlayedTime: Double
}
extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

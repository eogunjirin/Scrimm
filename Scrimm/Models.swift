import Foundation
import SwiftUI
import AVKit

// --- SHARED DATA MODEL ---
class SharedPlayerModel: ObservableObject {
    @Published var currentVideo: FoundVideo?
}

class NavigationModel: ObservableObject {
    @Published var destinationURL: URL?
    @Published var urlString: String = ""
    
    func reset() {
        DispatchQueue.main.async {
            self.destinationURL = nil
            self.urlString = ""
        }
    }
}

// --- RECENTS DATA MANAGER ---
class RecentsManager: ObservableObject {
    @Published var items: [RecentItem] = []
    private let recentsKey = "VideoRecents"

    init() { self.items = PersistenceController.shared.loadRecents() }

    // ** THIS IS THE DEFINITIVE FIX FOR THE TIME REGRESSION **
    func addOrUpdate(video: FoundVideo) {
        // Find if an item for this video already exists to preserve its time.
        let existingTime = items.first(where: { $0.urlString == video.videoURL.absoluteString })?.playbackTime ?? video.lastPlayedTime

        // Now, remove the old item.
        items.removeAll { $0.urlString == video.videoURL.absoluteString }
        
        // Create the new item, using the preserved time.
        let newItem = RecentItem(title: video.pageTitle, url: video.videoURL, playbackTime: existingTime)
        
        // Insert the updated item at the top of the list.
        items.insert(newItem, at: 0)
        
        if items.count > 10 {
            items = Array(items.prefix(10))
        }
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

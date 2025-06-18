import SwiftUI

@main
struct ScrimmApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Create single instances of our data managers.
    @StateObject private var playerModel = SharedPlayerModel()
    @StateObject private var recentsManager = RecentsManager()

    var body: some Scene {
        // ** THE DEFINITIVE FIX: Use `Window` instead of `WindowGroup`. **
        // This declares a single, unique main window for the app, which
        // correctly removes all tab-related menu items by default.
        Window("Scrimm", id: "main-window") {
            ContentView()
                .environmentObject(playerModel)
                .environmentObject(recentsManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            // This ensures "Reopen Window" works correctly from the Dock and removes "New".
            CommandGroup(replacing: .newItem) {}
        }
    }
}

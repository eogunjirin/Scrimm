import SwiftUI

@main
struct ScrimmApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Create single instances of our data managers.
    @StateObject private var playerModel = SharedPlayerModel()
    @StateObject private var recentsManager = RecentsManager()

    var body: some Scene {
        // We now ONLY define the main window group.
        // The player window is managed manually to guarantee a single instance
        // and to have full control over its appearance (no tabs).
        WindowGroup("Scrimm") {
            ContentView()
                .environmentObject(playerModel)
                .environmentObject(recentsManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            // This ensures "Reopen Window" works correctly from the Dock.
            CommandGroup(replacing: .newItem) {}
        }
    }
}

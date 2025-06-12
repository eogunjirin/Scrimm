import SwiftUI

@main
struct ScrimmApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // --- THESE MODIFIERS CREATE THE CLEAN, TITLE-LESS LOOK ---
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
}

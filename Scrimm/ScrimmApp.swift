import SwiftUI

@main
struct ScrimmApp: App {
    
    // The @NSApplicationDelegateAdaptor property wrapper allows us to bridge the
    // modern SwiftUI App lifecycle with the traditional AppKit AppDelegate pattern.
    // This is essential for gaining low-level control over window and app events.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // --- Single Source of Truth ---
    // These @StateObject properties create a single, shared instance of each data
    // manager when the app launches. They are the definitive source of truth for
    // their respective domains and are injected into the SwiftUI environment
    // to be accessible by any view in the hierarchy.

    /// Manages the state of the currently playing video for the detached player window.
    @StateObject private var playerModel = SharedPlayerModel()

    /// Manages the persistence and state of the "Recent Items" list.
    @StateObject private var recentsManager = RecentsManager()
    
    /// Manages the primary navigation state of the main window (launcher vs. browser).
    @StateObject private var navigationModel = NavigationModel()
    
    /// Manages the list of search providers loaded from `providers.json`.
    @StateObject private var providerManager = ProviderManager()

    var body: some Scene {
        
        // --- Main Application Window ---
        // We use `Window` instead of `WindowGroup` to declare a single, unique primary
        // window for the application. This is the correct scene type for a utility
        // app and correctly removes all default document-based menu items like "Tabs".
        Window("Scrimm", id: "main-window") {
            ContentView()
                // Inject all shared data models into the view hierarchy's environment.
                .environmentObject(playerModel)
                .environmentObject(recentsManager)
                .environmentObject(navigationModel)
                .environmentObject(providerManager)
                .onAppear {
                    // This is the critical bridge between the SwiftUI and AppKit worlds.
                    // When the ContentView appears, we pass a reference of our SwiftUI-managed
                    // navigationModel to the AppDelegate. The AppDelegate can now directly
                    // control the app's state in response to OS-level events.
                    appDelegate.navigationModel = navigationModel
                }
        }
        // Apply standard modern macOS window styling.
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            // This modifier removes the default "File > New" menu item (⌘N),
            // as it doesn't make sense for our single-window application.
            CommandGroup(replacing: .newItem) {}
        }
    }
}

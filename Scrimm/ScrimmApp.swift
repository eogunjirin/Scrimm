import SwiftUI

@main
struct ScrimmApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Create single instances of our data managers.
    @StateObject private var playerModel = SharedPlayerModel()
    @StateObject private var recentsManager = RecentsManager()
    @StateObject private var navigationModel = NavigationModel()

    var body: some Scene {
        Window("Scrimm", id: "main-window") {
            ContentView()
                .environmentObject(playerModel)
                .environmentObject(recentsManager)
                .environmentObject(navigationModel)
                // This is the key: pass the model to the delegate when the view appears.
                .onAppear {
                    appDelegate.navigationModel = navigationModel
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

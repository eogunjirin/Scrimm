import SwiftUI

@main
struct ScrimmApp: App { // <-- Make sure this matches your app's name
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // --- THIS IS THE KEY MODIFIER ---
        // It removes the title bar, allowing the content to extend to the top.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 700, height: 400) // Give it a nice default size
    }
}

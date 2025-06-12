import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    // This function tells the app to stay running in the background
    // after the user closes the main window.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // This function is called when the Dock icon is clicked.
    // It ensures that a new window is created if there isn't one already.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // This is a robust way to bring the window back.
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
}

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    // This method is called after the app has launched and its initial windows are set up.
    func applicationDidFinishLaunching(_ notification: Notification) {
        // ** THE DEFINITIVE FIX: Iterate through all windows and disable tabbing. **
        for window in NSApplication.shared.windows {
            window.tabbingMode = .disallowed
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // This is correct. It keeps the app alive in the dock.
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // If there are no visible windows, this brings the main window back.
        if !flag {
            for window in sender.windows {
                if window.title == "Scrimm" {
                    window.makeKeyAndOrderFront(self)
                    return true
                }
            }
        }
        return true
    }
}

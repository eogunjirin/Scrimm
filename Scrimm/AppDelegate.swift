import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
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

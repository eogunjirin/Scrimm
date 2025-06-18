import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    // A weak reference to the navigation model to avoid retain cycles.
    weak var navigationModel: NavigationModel?
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep app running in the dock.
    }

    // ** THIS IS THE DEFINITIVE FIX **
    // This is called when the user clicks the Dock icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // If there are no visible windows (e.g., the user closed the main window)...
        if !flag {
            // ...reset the navigation state to nil BEFORE showing the window.
            navigationModel?.reset()
            
            // Then, find the main window and bring it to the front.
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

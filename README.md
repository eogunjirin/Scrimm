Scrimm
Scrimm is a sleek, minimalist video launcher for macOS designed to get you from a web page to its native video content as quickly as possible. It provides a streamlined, single-window experience that cuts through the noise of web pages, offering a clean browsing environment and transitioning seamlessly to a native video player once a video is detected.
(Note: You should replace this with a screenshot of your actual app!)
Description
Tired of digging through websites cluttered with ads and other elements just to watch a video? Scrimm solves this by providing a simple utility to enter a URL, browse within a sandboxed in-app browser, and have the app automatically detect and open video streams in a clean, native macOS video player.
The app remembers your recently played videos (using the page title for clarity), allowing you to jump straight back into the content with a single click.
How It Works
Enter a URL: The launcher prompts you to enter a URL.
Browse In-App: The URL opens in a minimalist, in-app web view within the same window.
Auto-Detect & Play: Scrimm uses a combination of JavaScript injection and navigation interception to intelligently detect video URLs (.mp4, .m3u8, etc.). Once a video is found, the view automatically transitions to the native macOS player for smooth, efficient playback.
Revisit with Recents: Videos that are successfully opened in the native player are automatically added to a "Recents" list on the launcher screen, saving the page's title for easy identification.
Core Features
Single-Window Navigation: The entire app experience—launcher, browser, and player—is contained within a single, state-driven window.
Intelligent Video Discovery: Actively listens for video content on web pages using robust WebKit features.
Native Video Playback: Utilizes Apple's AVKit framework for high-performance, low-latency video playback.
Persistent Recents List: Remembers your last 5 successfully played videos, storing them locally using UserDefaults.
Modern macOS UI: Features a title-less, translucent window design that integrates beautifully with the macOS desktop.
Standard App Behavior: The app remains running in the Dock when the window is closed, allowing for quick re-launching, as expected from a modern macOS utility.
Getting Started (For Users)
To run Scrimm on your Mac without building it yourself:
Go to the Releases page of this repository.
Download the latest .zip or .dmg file from the "Assets" section.
If you downloaded a .zip file, unzip it.
Drag the Scrimm.app file into your computer's /Applications folder.
Important: The first time you run the app, macOS Gatekeeper may show a security warning. To bypass this, right-click on the Scrimm.app icon and select "Open" from the context menu. You will only need to do this once.
Building from Source (For Developers)
If you'd like to build the project yourself, follow these steps.
Prerequisites
macOS 14.0 (Sonoma) or later
Xcode 15.0 or later
Build Steps
Clone the repository:
git clone https://github.com/your-username/your-repo-name.git
Use code with caution.
Sh
Navigate to the project directory:
cd your-repo-name
Use code with caution.
Sh
Open the project in Xcode:
open Scrimm.xcodeproj
Use code with caution.
Sh
In Xcode, select My Mac as the run destination.
Press ⌘R to build and run the app.
The project is self-contained and does not require any external dependencies.
Technical Stack
Scrimm is built entirely with modern Apple technologies:
UI Framework: SwiftUI
Web Content: WebKit (WKWebView)
Video Playback: AVKit (AVPlayer)
App Lifecycle: NSApplicationDelegate for window management
Persistence: UserDefaults with Codable for the recents list
License
This project is licensed under the MIT License. See the LICENSE file for details.

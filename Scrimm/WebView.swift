import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    var onVideoFound: (FoundVideo) -> Void

    func makeNSView(context: Context) -> WKWebView {
        // --- THIS SCRIPT IS NOW SIGNIFICANTLY MORE POWERFUL ---
        let scriptSource = """
            (function() {
                const foundUrls = new Set();
                
                // This is our single function to send a URL back to the app.
                function sendVideoUrl(urlString) {
                    // Basic validation to avoid sending blobs or duplicates.
                    if (!urlString || typeof urlString !== 'string' || urlString.startsWith('blob:')) {
                        return;
                    }
                    if (!foundUrls.has(urlString)) {
                        foundUrls.add(urlString);
                        console.log('Found Potential Video Source: ' + urlString);
                        window.webkit.messageHandlers.videoPlayback.postMessage(urlString);
                    }
                }

                // --- METHOD 1: Monkey-patch 'fetch' (for modern websites) ---
                const originalFetch = window.fetch;
                window.fetch = function() {
                    const resource = arguments[0];
                    let urlString = resource instanceof Request ? resource.url : resource;
                    
                    // Check if the requested URL is a video/manifest file.
                    if (typeof urlString === 'string' && (urlString.includes('.m3u8') || urlString.includes('.mp4'))) {
                        sendVideoUrl(urlString);
                    }
                    
                    // IMPORTANT: Call the original fetch so the website works normally.
                    return originalFetch.apply(this, arguments);
                };

                // --- METHOD 2: Monkey-patch 'XMLHttpRequest' (for older websites) ---
                const originalOpen = XMLHttpRequest.prototype.open;
                XMLHttpRequest.prototype.open = function() {
                    let urlString = arguments[1];

                    if (typeof urlString === 'string' && (urlString.includes('.m3u8') || urlString.includes('.mp4'))) {
                        sendVideoUrl(urlString);
                    }
                    
                    // IMPORTANT: Call the original open method.
                    originalOpen.apply(this, arguments);
                };

                // --- METHOD 3: Your original <video> tag scanner (still useful!) ---
                // This will catch videos that are directly embedded in the HTML.
                setInterval(() => {
                    document.querySelectorAll('video, source').forEach(element => {
                        if (element.src) {
                            sendVideoUrl(element.src);
                        }
                    });
                }, 1500); // Check every 1.5 seconds.
            })();
        """
        
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        let contentController = WKUserContentController()
        contentController.addUserScript(userScript)
        contentController.add(context.coordinator, name: "videoPlayback")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // --- The Coordinator is now back to your original, working version ---
    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        // Use a flag to ensure we only transition once.
        private var hasFoundVideo = false

        init(_ parent: WebView) {
            self.parent = parent
        }

        // Reset the flag on new page loads.
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            hasFoundVideo = false
        }
        
        // This handles links that try to open in a new window.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // If the pop-up link is a video, grab it.
            if let url = navigationAction.request.url {
                let pathExtension = url.pathExtension.lowercased()
                if ["mp4", "mov", "m3u8"].contains(pathExtension) && !hasFoundVideo {
                    hasFoundVideo = true
                    let pageTitle = webView.title ?? "Untitled Video"
                    let videoInfo = FoundVideo(pageTitle: pageTitle, videoURL: url, lastPlayedTime: 0.0)
                    parent.onVideoFound(videoInfo)
                }
            }
            // Always return nil to block the pop-up.
            return nil
        }

        // This handles messages from our JavaScript.
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "videoPlayback", let videoURLString = message.body as? String, !hasFoundVideo {
                var finalVideoURL: URL?

                if videoURLString.lowercased().hasPrefix("http") {
                    finalVideoURL = URL(string: videoURLString)
                } else {
                    if let pageURL = message.frameInfo.request.url {
                        finalVideoURL = URL(string: videoURLString, relativeTo: pageURL)
                    }
                }
                
                if let finalURL = finalVideoURL {
                    hasFoundVideo = true
                    let pageTitle = message.webView?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled Video"
                    let videoInfo = FoundVideo(
                        pageTitle: pageTitle.isEmpty ? "Untitled Video" : pageTitle,
                        videoURL: finalURL,
                        lastPlayedTime: 0.0
                    )
                    DispatchQueue.main.async {
                        self.parent.onVideoFound(videoInfo)
                    }
                }
            }
        }
    }
}

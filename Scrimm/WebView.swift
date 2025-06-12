import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    var onVideoFound: (URL) -> Void

    // This part remains the same.
    func makeNSView(context: Context) -> WKWebView {
        let scriptSource = """
            (function() {
                const foundUrls = new Set();
                function sendVideoUrl(urlString) {
                    if (!urlString || typeof urlString !== 'string' || urlString.startsWith('blob:')) { return; }
                    if (!foundUrls.has(urlString)) {
                        foundUrls.add(urlString);
                        console.log('Found video via JavaScript: ' + urlString);
                        window.webkit.messageHandlers.videoPlayback.postMessage(urlString);
                    }
                }
                const observer = new MutationObserver(mutations => {
                    mutations.forEach(mutation => {
                        if (mutation.type === 'attributes' && mutation.attributeName === 'src' && mutation.target.tagName === 'VIDEO') {
                            sendVideoUrl(mutation.target.src);
                        }
                    });
                });
                document.addEventListener('play', event => {
                    if (event.target.tagName === 'VIDEO') { sendVideoUrl(event.target.currentSrc || event.target.src); }
                }, true);
                setInterval(() => {
                    document.querySelectorAll('video').forEach(video => {
                        observer.observe(video, { attributes: true });
                        sendVideoUrl(video.currentSrc || video.src);
                    });
                }, 1000);
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

    // --- The Coordinator is where the new logic is added. ---
    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        // --- METHOD 2: NAVIGATION INTERCEPTION ---
        // This watches for pop-ups or navigation attempts to video files.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                print("[Navigation Interceptor] Intercepted URL: \(url)")
                let pathExtension = url.pathExtension.lowercased()
                let videoExtensions = ["mp4", "mov", "m4v", "m3u8"] // Common video/stream formats
                
                if videoExtensions.contains(pathExtension) {
                    print("[Navigation Interceptor] Found video link! Transferring to native player.")
                    // It's a video link, pass it to our app.
                    parent.onVideoFound(url)
                }
                // For anything else, we block it silently by doing nothing.
            }
            // Returning nil prevents the new window from opening.
            return nil
        }

        // --- METHOD 1: JAVASCRIPT MESSAGE HANDLER ---
        // This handles URLs found by our powerful injected script.
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "videoPlayback", let videoURLString = message.body as? String {
                print("[JavaScript Interceptor] Received URL string: \(videoURLString)")
                var finalVideoURL: URL?

                if videoURLString.lowercased().hasPrefix("http") {
                    finalVideoURL = URL(string: videoURLString)
                } else {
                    if let pageURL = message.frameInfo.request.url {
                        finalVideoURL = URL(string: videoURLString, relativeTo: pageURL)
                    }
                }
                
                if let finalURL = finalVideoURL {
                    print("[JavaScript Interceptor] Successfully resolved URL. Transferring to native player.")
                    DispatchQueue.main.async {
                        self.parent.onVideoFound(finalURL)
                    }
                } else {
                    print("[JavaScript Interceptor] Failed to resolve URL.")
                }
            }
        }
    }
}

import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    let webView: WKWebView // Now passed in from the parent view
    var onVideoFound: (FoundVideo) -> Void

    private static let universalMediaInterceptorScript = #"""
        (function() {
            const foundUrls = new Set();
            let lastSeenManifestUrl = null;

            function sendUrlToSwift(urlString) {
                if (!urlString || typeof urlString !== 'string' || urlString.startsWith('blob:')) return;
                if (foundUrls.has(urlString)) return;
                foundUrls.add(urlString);
                window.webkit.messageHandlers.videoPlayback.postMessage(urlString);
            }

            const spyOnNetwork = (url) => {
                if (typeof url === 'string' && (url.includes('.m3u8') || url.includes('.mp4'))) {
                    if (url.includes('.m3u8')) { lastSeenManifestUrl = url; }
                    sendUrlToSwift(url);
                }
            };
            const originalFetch = window.fetch;
            window.fetch = function(...args) { spyOnNetwork(args[0] instanceof Request ? args[0].url : args[0]); return originalFetch.apply(this, args); };
            const originalOpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function(...args) { spyOnNetwork(args[1]); originalOpen.apply(this, args); };

            const originalCreateObjectURL = URL.createObjectURL;
            URL.createObjectURL = function(object) {
                if (object instanceof MediaSource && lastSeenManifestUrl) { sendUrlToSwift(lastSeenManifestUrl); }
                return originalCreateObjectURL.apply(this, arguments);
            };

            const observer = new MutationObserver((mutations) => {
                for (const mutation of mutations) {
                    const checkNode = (node) => {
                        if (node.tagName === 'VIDEO' || node.tagName === 'SOURCE') { if (node.src) sendUrlToSwift(node.src); }
                        if (node.querySelectorAll) { node.querySelectorAll('video, source').forEach(el => { if (el.src) sendUrlToSwift(el.src); }); }
                    };
                    mutation.addedNodes.forEach(checkNode);
                    if (mutation.type === 'attributes' && mutation.attributeName === 'src') { checkNode(mutation.target); }
                }
            });
            const startObserver = () => { if (document.body) { observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['src'] }); } };
            if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', startObserver); } 
            else { startObserver(); }
        })();
    """#

    func makeNSView(context: Context) -> WKWebView {
        let contentController = webView.configuration.userContentController
        contentController.removeAllUserScripts()
        contentController.removeScriptMessageHandler(forName: "videoPlayback") // Ensure clean state
        
        let script = WKUserScript(source: WebView.universalMediaInterceptorScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(script)
        contentController.add(context.coordinator, name: "videoPlayback")
        
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        private var hasFoundVideoOnThisPage = false

        init(_ parent: WebView) { self.parent = parent }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            hasFoundVideoOnThisPage = false
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "videoPlayback", let videoURLString = message.body as? String, !hasFoundVideoOnThisPage {
                
                var finalVideoURL: URL?
                if videoURLString.lowercased().hasPrefix("http") {
                    finalVideoURL = URL(string: videoURLString)
                } else if let pageURL = message.webView?.url {
                    finalVideoURL = URL(string: videoURLString, relativeTo: pageURL)
                }
                
                if let finalURL = finalVideoURL {
                    hasFoundVideoOnThisPage = true
                    let pageTitle = message.webView?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled Video"
                    let videoInfo = FoundVideo(pageTitle: pageTitle.isEmpty ? "Untitled Video" : pageTitle, videoURL: finalURL, lastPlayedTime: 0.0)
                    DispatchQueue.main.async {
                        self.parent.onVideoFound(videoInfo)
                    }
                }
            }
        }
    }
}

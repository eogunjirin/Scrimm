import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    let webView: WKWebView
    var onVideoFound: (FoundVideo) -> Void

    private static let universalMediaInterceptorScript = #"""
        (function() {
            // --- STATE & CONFIGURATION ---
            const foundUrls = new Set();
            let lastSeenManifestUrl = null;

            // --- CORE FUNCTIONS ---
            function sendUrlToSwift(urlString) {
                if (!urlString || typeof urlString !== 'string' || urlString.startsWith('blob:')) return;
                if (foundUrls.has(urlString)) return;
                foundUrls.add(urlString);
                console.log('>>> Scrimm Found Video: ' + urlString);
                window.webkit.messageHandlers.videoPlayback.postMessage(urlString);
            }

            function resetVideoDetector() {
                console.log('>>> Scrimm Detector Resetting...');
                foundUrls.clear();
                // Send a message to Swift to reset its gatekeeper flag.
                window.webkit.messageHandlers.resetDetector.postMessage(true);
            }

            // --- DETECTION VECTORS ---

            // Vector 1: Network Request Interception
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

            // Vector 2: MediaSource Hooking
            const originalCreateObjectURL = URL.createObjectURL;
            URL.createObjectURL = function(object) {
                if (object instanceof MediaSource && lastSeenManifestUrl) { sendUrlToSwift(lastSeenManifestUrl); }
                return originalCreateObjectURL.apply(this, arguments);
            };

            // Vector 3: DOM Mutation Observer
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

            // ** NEW ** Vector 4: Periodic Deep Scan for obfuscated sources
            const deepScan = () => {
                // Scan JSON-LD structured data
                document.querySelectorAll('script[type="application/ld+json"]').forEach(script => {
                    try {
                        const data = JSON.parse(script.textContent);
                        if (data.contentUrl) sendUrlToSwift(data.contentUrl);
                        if (data.embedUrl) sendUrlToSwift(data.embedUrl);
                    } catch (e) {}
                });

                // Scan global window object for obfuscated/encoded URLs
                for (const key in window) {
                    try {
                        if (typeof window[key] === 'string' && window[key].length > 100) {
                            // Base64 check for hidden manifests
                            if (window[key].startsWith('ey')) {
                                const decoded = atob(window[key]);
                                if (decoded.includes('.m3u8') || decoded.includes('.mp4')) {
                                    const urlMatch = decoded.match(/https?:\/\/[^"'\s]+/);
                                    if(urlMatch) sendUrlToSwift(urlMatch[0]);
                                }
                            }
                        }
                    } catch (e) {}
                }
            };
            
            // --- LIFECYCLE & EVENT HANDLING ---
            if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', startObserver); } 
            else { startObserver(); }

            document.addEventListener('click', (event) => {
                const target = event.target;
                const playerKeywords = ['video', 'player', 'thumbnail', 'play-button', 'episode'];
                let element = target;
                let shouldReset = false;
                while(element && element !== document.body) {
                    const classList = (element.className || "").toLowerCase();
                    const id = (element.id || "").toLowerCase();
                    if (playerKeywords.some(keyword => classList.includes(keyword) || id.includes(keyword))) {
                        shouldReset = true;
                        break;
                    }
                    element = element.parentElement;
                }
                if (shouldReset) {
                    resetVideoDetector();
                }
            }, true);
            
            // Run the deep scan periodically to catch anything missed.
            setInterval(deepScan, 2500);
        })();
    """#

    func makeNSView(context: Context) -> WKWebView {
        let contentController = webView.configuration.userContentController
        contentController.removeAllUserScripts()
        contentController.removeScriptMessageHandler(forName: "videoPlayback")
        contentController.removeScriptMessageHandler(forName: "resetDetector")
        
        let script = WKUserScript(source: WebView.universalMediaInterceptorScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(script)
        
        contentController.add(context.coordinator, name: "videoPlayback")
        contentController.add(context.coordinator, name: "resetDetector")
        
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
            if message.name == "resetDetector" {
                self.hasFoundVideoOnThisPage = false
                return
            }

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

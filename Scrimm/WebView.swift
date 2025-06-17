import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    var onVideoFound: (FoundVideo) -> Void

    private static let sanitizerScriptSource = """
        const style = document.createElement('style');
        style.textContent = `
            .ad, .ads, .advert, .advertisement, .banner-ad, .google-ads, [id*="google_ads"], 
            [class*="google_ads"], #ad-container, .ad-wrapper, .ad-banner, .ad-slot, 
            .ad-block, [aria-label*="advertisement"], .trc_rbox_div, .OUTBRAIN, 
            .taboola, [id*="taboola"], [id*="outbrain"], #cookie-banner, .cookie-consent, 
            #onetrust-banner-sdk, .gdpr-consent, .privacy-prompt, #newsletter-signup, 
            .modal-overlay, .popup-content, .tp-modal, .tp-backdrop, [class*="sp_message"],
            [id*="sp_message"], .ad-placeholder, [class*="ad-"] {
                display: none !important;
                visibility: hidden !important;
                position: absolute !important;
                left: -9999px !important;
                top: -9999px !important;
                z-index: -1000 !important;
            }
        `;
        document.documentElement.insertBefore(style, document.head);
        const observer = new MutationObserver((mutations) => {
            for (const mutation of mutations) {
                mutation.addedNodes.forEach(node => {
                    if (node.nodeType === 1) {
                        const el = node;
                        const className = (el.className || "").toLowerCase();
                        const id = (el.id || "").toLowerCase();
                        const annoyanceKeywords = ['modal', 'popup', 'backdrop', 'consent', 'banner', 'promo', 'overlay', 'dialog'];
                        if (annoyanceKeywords.some(keyword => className.includes(keyword) || id.includes(keyword))) {
                            el.style.setProperty('display', 'none', 'important');
                        }
                    }
                });
            }
        });
        const startObserver = () => { if (document.body) { observer.observe(document.body, { childList: true, subtree: true }); } };
        if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', startObserver); } else { startObserver(); }
    """

    private static let videoFinderScriptSource = #"""
        (function() {
            const foundUrls = new Set();
            function sendUrlToSwift(urlString) {
                if (!urlString || typeof urlString !== 'string' || urlString.startsWith('blob:')) return;
                if (foundUrls.has(urlString)) return;
                foundUrls.add(urlString);
                window.webkit.messageHandlers.videoPlayback.postMessage(urlString);
            }
            const originalFetch = window.fetch;
            window.fetch = function(...args) { const url = args[0] instanceof Request ? args[0].url : args[0]; if(typeof url === 'string' && (url.includes('.m3u8') || url.includes('.mp4'))){ sendUrlToSwift(url); } return originalFetch.apply(this, args); };
            const originalOpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function(...args) { const url = args[1]; if(typeof url === 'string' && (url.includes('.m3u8') || url.includes('.mp4'))){ sendUrlToSwift(url); } originalOpen.apply(this, args); };
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
            if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', startObserver); } else { startObserver(); }
        })();
    """#

    func makeNSView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        let sanitizingScript = WKUserScript(source: WebView.sanitizerScriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        let videoFinderScript = WKUserScript(source: WebView.videoFinderScriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(sanitizingScript); contentController.addUserScript(videoFinderScript)
        contentController.add(context.coordinator, name: "videoPlayback")
        let configuration = WKWebViewConfiguration(); configuration.userContentController = contentController
        ContentBlocker.apply(to: contentController)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator; webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView; private var hasFoundVideoOnThisPage = false
        init(_ parent: WebView) { self.parent = parent }
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { hasFoundVideoOnThisPage = false }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "videoPlayback", let videoURLString = message.body as? String, !hasFoundVideoOnThisPage {
                var finalVideoURL: URL?
                if videoURLString.lowercased().hasPrefix("http") { finalVideoURL = URL(string: videoURLString) }
                else if let pageURL = message.webView?.url { finalVideoURL = URL(string: videoURLString, relativeTo: pageURL) }
                if let finalURL = finalVideoURL {
                    hasFoundVideoOnThisPage = true
                    let pageTitle = message.webView?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled Video"
                    let videoInfo = FoundVideo(pageTitle: pageTitle.isEmpty ? "Untitled Video" : pageTitle, videoURL: finalURL, lastPlayedTime: 0.0)
                    DispatchQueue.main.async { self.parent.onVideoFound(videoInfo) }
                }
            }
        }
    }
}

class ContentBlocker {
    private static var ruleList: WKContentRuleList?
    static func apply(to contentController: WKUserContentController) {
        if let ruleList = self.ruleList { contentController.add(ruleList); return }
        guard let path = Bundle.main.path(forResource: "blockerList", ofType: "json"), let blockerListString = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "adBlockerRules", encodedContentRuleList: blockerListString) { (compiledList, error) in
            if let error = error { print("Error compiling content blocker: \(error.localizedDescription)"); return }
            self.ruleList = compiledList
            if let list = compiledList { contentController.add(list) }
        }
    }
}

import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    // **CHANGE 1: The completion handler now sends back a `FoundVideo` object.**
    var onVideoFound: (FoundVideo) -> Void

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

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                let pathExtension = url.pathExtension.lowercased()
                let videoExtensions = ["mp4", "mov", "m4v", "m3u8"]
                
                if videoExtensions.contains(pathExtension) {
                    // **CHANGE 2: Get the page title and package it with the URL.**
                    let pageTitle = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled Video"
                    let videoInfo = FoundVideo(
                        pageTitle: pageTitle.isEmpty ? "Untitled Video" : pageTitle,
                        videoURL: url
                    )
                    parent.onVideoFound(videoInfo)
                }
            }
            return nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "videoPlayback", let videoURLString = message.body as? String {
                var finalVideoURL: URL?

                if videoURLString.lowercased().hasPrefix("http") {
                    finalVideoURL = URL(string: videoURLString)
                } else {
                    if let pageURL = message.frameInfo.request.url {
                        finalVideoURL = URL(string: videoURLString, relativeTo: pageURL)
                    }
                }
                
                if let finalURL = finalVideoURL {
                    // **CHANGE 3: Get the page title from the message's webView and package it.**
                    let pageTitle = message.webView?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled Video"
                    let videoInfo = FoundVideo(
                        pageTitle: pageTitle.isEmpty ? "Untitled Video" : pageTitle,
                        videoURL: finalURL
                    )
                    DispatchQueue.main.async {
                        self.parent.onVideoFound(videoInfo)
                    }
                }
            }
        }
    }
}

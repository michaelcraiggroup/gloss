import SwiftUI
import WebKit

/// UIViewRepresentable twin of the macOS read-mode WebView, carrying over the
/// portable behaviors only: HTML load with dedupe, the link-interception
/// policy (anchors scroll in-page, wiki-links post `.glossNavigateWikiLink`,
/// http(s) leaves the app), load-state notifications, and search-highlight
/// re-apply on load. Deliberately dropped for v1: drag/drop, context menus,
/// print/PDF export, `pageZoom` (macOS-only API — font size is the iOS zoom),
/// and the guide/template script bridges (macOS-only features).
struct ReaderWebView: UIViewRepresentable {
    let htmlContent: String
    let baseURL: URL?
    var highlightQuery: String?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        // Let the rendered document's CSS background own the surface (avoids
        // the opaque-white flash before first paint in dark mode).
        webView.isOpaque = false
        webView.backgroundColor = .clear
        context.coordinator.webView = webView
        context.coordinator.lastHTML = htmlContent
        context.coordinator.pendingHighlight = highlightQuery
        webView.loadHTMLString(htmlContent, baseURL: baseURL)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.pendingHighlight = highlightQuery
        if htmlContent != context.coordinator.lastHTML {
            context.coordinator.lastHTML = htmlContent
            webView.loadHTMLString(htmlContent, baseURL: baseURL)
            // Highlight re-applies in didFinish.
        } else if highlightQuery != context.coordinator.activeHighlight {
            context.coordinator.applyHighlight(highlightQuery)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, @unchecked Sendable {
        weak var webView: WKWebView?
        var lastHTML: String?
        var pendingHighlight: String?
        var activeHighlight: String?

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            MainActor.assumeIsolated {
                NotificationCenter.default.post(name: .glossWebViewDidStartLoad, object: nil)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            MainActor.assumeIsolated {
                applyHighlight(pendingHighlight)
                NotificationCenter.default.post(name: .glossWebViewDidFinishLoad, object: nil)
            }
        }

        // Same policy as macOS WebView.decidePolicyFor — anchors, wiki-links,
        // external links; everything else loads in place.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if url.fragment != nil && (url.scheme == nil || url.scheme == "about") {
                let escaped = url.fragment!.replacingOccurrences(of: "'", with: "\\'")
                let js = "document.getElementById('\(escaped)')?.scrollIntoView({behavior:'smooth',block:'start'})"
                MainActor.assumeIsolated {
                    webView.evaluateJavaScript(js, completionHandler: nil)
                }
                decisionHandler(.cancel)
                return
            }

            if url.isFileURL, ["md", "markdown"].contains(url.pathExtension.lowercased()) {
                MainActor.assumeIsolated {
                    NotificationCenter.default.post(name: .glossNavigateWikiLink, object: url)
                }
                decisionHandler(.cancel)
                return
            }

            if url.scheme == "http" || url.scheme == "https" {
                MainActor.assumeIsolated {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func applyHighlight(_ query: String?) {
            activeHighlight = query
            guard let query, !query.isEmpty else {
                webView?.evaluateJavaScript("clearHighlights()", completionHandler: nil)
                return
            }
            let escaped = query.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            webView?.evaluateJavaScript("performFind('\(escaped)')", completionHandler: nil)
        }
    }
}

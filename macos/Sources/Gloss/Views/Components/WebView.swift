import SwiftUI
import WebKit

/// NSViewRepresentable wrapper around WKWebView for rendering HTML content.
struct WebView: NSViewRepresentable {
    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
        DispatchQueue.main.async {
            webView.window?.makeFirstResponder(webView)
        }
    }
}

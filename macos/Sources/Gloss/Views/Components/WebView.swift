import SwiftUI
import WebKit

extension Notification.Name {
    static let glossFindInPage = Notification.Name("glossFindInPage")
    static let glossFindNext = Notification.Name("glossFindNext")
    static let glossFindPrevious = Notification.Name("glossFindPrevious")
}

/// NSViewRepresentable wrapper around WKWebView for rendering HTML content.
struct WebView: NSViewRepresentable {
    let htmlContent: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
        DispatchQueue.main.async {
            webView.window?.makeFirstResponder(webView)
        }
    }

    class Coordinator: NSObject, @unchecked Sendable {
        weak var webView: WKWebView?
        private var observers: [Any] = []

        override init() {
            super.init()
            let names: [(Notification.Name, String)] = [
                (.glossFindInPage, "glossToggleFindBar()"),
                (.glossFindNext, "glossFindNext()"),
                (.glossFindPrevious, "glossFindPrevious()"),
            ]
            for (name, js) in names {
                observers.append(
                    NotificationCenter.default.addObserver(
                        forName: name, object: nil, queue: .main
                    ) { [weak self] _ in
                        MainActor.assumeIsolated {
                            self?.webView?.evaluateJavaScript(js, completionHandler: nil)
                        }
                    }
                )
            }
        }

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

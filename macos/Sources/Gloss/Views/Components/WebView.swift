import SwiftUI
import WebKit

extension Notification.Name {
    static let glossFindInPage = Notification.Name("glossFindInPage")
    static let glossFindNext = Notification.Name("glossFindNext")
    static let glossFindPrevious = Notification.Name("glossFindPrevious")
    static let glossFileDrop = Notification.Name("glossFileDrop")
    static let glossPrint = Notification.Name("glossPrint")
}

/// WKWebView subclass that intercepts markdown file drops.
@MainActor
class DropAcceptingWebView: WKWebView {
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if hasMarkdownFile(sender) { return .copy }
        return super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if hasMarkdownFile(sender) { return .copy }
        return super.draggingUpdated(sender)
    }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if hasMarkdownFile(sender) { return true }
        return super.prepareForDragOperation(sender)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if let url = markdownURL(from: sender) {
            NotificationCenter.default.post(name: .glossFileDrop, object: url)
            return true
        }
        return super.performDragOperation(sender)
    }

    private func hasMarkdownFile(_ info: any NSDraggingInfo) -> Bool {
        markdownURL(from: info) != nil
    }

    private func markdownURL(from info: any NSDraggingInfo) -> URL? {
        guard let items = info.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
              let url = items.first,
              ["md", "markdown"].contains(url.pathExtension.lowercased()) else {
            return nil
        }
        return url
    }
}

/// NSViewRepresentable wrapper around WKWebView for rendering HTML content.
struct WebView: NSViewRepresentable {
    let htmlContent: String
    var highlightQuery: String?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = DropAcceptingWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let contentChanged = htmlContent != context.coordinator.lastHTML
        context.coordinator.pendingHighlight = highlightQuery

        if contentChanged {
            context.coordinator.lastHTML = htmlContent
            webView.loadHTMLString(htmlContent, baseURL: nil)
            // highlight will be applied in didFinishNavigation
        } else if highlightQuery != context.coordinator.activeHighlight {
            // Content same but query changed — apply highlight now
            context.coordinator.applyHighlight(highlightQuery)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, @unchecked Sendable {
        weak var webView: WKWebView?
        var lastHTML: String?
        var pendingHighlight: String?
        var activeHighlight: String?
        nonisolated(unsafe) private var observers: [Any] = []

        override init() {
            super.init()
            let names: [(Notification.Name, String)] = [
                (.glossFindInPage, "glossToggleFindBar()"),
                (.glossFindNext, "glossFindNext()"),
                (.glossFindPrevious, "glossFindPrevious()"),
                (.glossPrint, "window.print()"),
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

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            MainActor.assumeIsolated {
                applyHighlight(pendingHighlight)
            }
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

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

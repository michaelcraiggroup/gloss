import SwiftUI
import WebKit

extension Notification.Name {
    static let glossFindInPage = Notification.Name("glossFindInPage")
    static let glossFindNext = Notification.Name("glossFindNext")
    static let glossFindPrevious = Notification.Name("glossFindPrevious")
    static let glossFileDrop = Notification.Name("glossFileDrop")
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

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = DropAcceptingWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard htmlContent != context.coordinator.lastHTML else { return }
        context.coordinator.lastHTML = htmlContent
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }

    class Coordinator: NSObject, @unchecked Sendable {
        weak var webView: WKWebView?
        var lastHTML: String?
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

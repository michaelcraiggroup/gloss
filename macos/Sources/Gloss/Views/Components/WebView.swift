import SwiftUI
import WebKit

extension Notification.Name {
    static let glossFindInPage = Notification.Name("glossFindInPage")
    static let glossFindNext = Notification.Name("glossFindNext")
    static let glossFindPrevious = Notification.Name("glossFindPrevious")
    static let glossFileDrop = Notification.Name("glossFileDrop")
    static let glossPrint = Notification.Name("glossPrint")
    static let glossExportPDF = Notification.Name("glossExportPDF")
    static let glossScrollToHeading = Notification.Name("glossScrollToHeading")
    static let glossDocumentLoaded = Notification.Name("glossDocumentLoaded")
    static let glossNavigateWikiLink = Notification.Name("glossNavigateWikiLink")
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
    var baseURL: URL?
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
            webView.loadHTMLString(htmlContent, baseURL: baseURL)
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
            observers.append(
                NotificationCenter.default.addObserver(
                    forName: .glossPrint, object: nil, queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let webView = self?.webView else { return }
                        let printInfo = NSPrintInfo.shared
                        printInfo.isHorizontallyCentered = true
                        printInfo.isVerticallyCentered = false
                        let op = webView.printOperation(with: printInfo)
                        op.showsPrintPanel = true
                        op.showsProgressPanel = true
                        op.runModal(for: webView.window ?? NSApp.keyWindow ?? NSWindow(),
                                    delegate: nil, didRun: nil, contextInfo: nil)
                    }
                }
            )
            // Scroll to heading (from inspector TOC click)
            observers.append(
                NotificationCenter.default.addObserver(
                    forName: .glossScrollToHeading, object: nil, queue: .main
                ) { [weak self] notification in
                    let headingID = notification.object as? String
                    MainActor.assumeIsolated {
                        guard let headingID else { return }
                        let escaped = headingID.replacingOccurrences(of: "'", with: "\\'")
                        let js = "document.getElementById('\(escaped)')?.scrollIntoView({behavior:'smooth',block:'start'})"
                        self?.webView?.evaluateJavaScript(js, completionHandler: nil)
                    }
                }
            )
            // Export as PDF
            observers.append(
                NotificationCenter.default.addObserver(
                    forName: .glossExportPDF, object: nil, queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.exportPDF()
                    }
                }
            )
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            MainActor.assumeIsolated {
                applyHighlight(pendingHighlight)
            }
        }

        // Intercept link clicks — handle anchor links and wiki-link navigation
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

            // Anchor links within the same page
            if url.fragment != nil && (url.scheme == nil || url.scheme == "about") {
                let fragment = url.fragment!
                let escaped = fragment.replacingOccurrences(of: "'", with: "\\'")
                let js = "document.getElementById('\(escaped)')?.scrollIntoView({behavior:'smooth',block:'start'})"
                MainActor.assumeIsolated {
                    webView.evaluateJavaScript(js, completionHandler: nil)
                }
                decisionHandler(.cancel)
                return
            }

            // Local markdown file links (wiki-links resolve to file:// paths)
            if url.isFileURL, ["md", "markdown"].contains(url.pathExtension.lowercased()) {
                MainActor.assumeIsolated {
                    NotificationCenter.default.post(name: .glossNavigateWikiLink, object: url)
                }
                decisionHandler(.cancel)
                return
            }

            // External URLs — open in default browser
            if url.scheme == "http" || url.scheme == "https" {
                MainActor.assumeIsolated { _ = NSWorkspace.shared.open(url) }
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

        private func exportPDF() {
            guard let webView else { return }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = "document.pdf"
            panel.title = "Export as PDF"
            guard panel.runModal() == .OK, let saveURL = panel.url else { return }

            webView.createPDF { result in
                switch result {
                case .success(let data):
                    try? data.write(to: saveURL)
                case .failure:
                    break
                }
            }
        }

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

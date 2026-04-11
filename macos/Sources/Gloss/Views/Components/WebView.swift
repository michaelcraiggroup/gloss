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
    static let glossShowPaywall = Notification.Name("glossShowPaywall")
    static let glossGuideReady = Notification.Name("glossGuideReady")
    static let glossGuideStepComplete = Notification.Name("glossGuideStepComplete")
    static let glossGuideStopped = Notification.Name("glossGuideStopped")
    static let glossGuideDispatchWeb = Notification.Name("glossGuideDispatchWeb")
    static let glossGuideStopWeb = Notification.Name("glossGuideStopWeb")
    static let glossIndexUpdated = Notification.Name("glossIndexUpdated")
}

/// WKWebView subclass that intercepts markdown file drops.
@MainActor
class DropAcceptingWebView: WKWebView {
    /// Shared reference for direct print/export access from menu commands.
    static weak var current: DropAcceptingWebView?

    /// Raw markdown source for the currently rendered document. Used by the
    /// "Copy Raw Markdown" context menu item.
    var rawMarkdown: String?

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Context Menu

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        guard rawMarkdown != nil else { return }
        let item = NSMenuItem(
            title: "Copy Raw Markdown",
            action: #selector(copyRawMarkdown(_:)),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(.separator())
        menu.addItem(item)
    }

    @objc private func copyRawMarkdown(_ sender: Any?) {
        guard let markdown = rawMarkdown else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
    }

    // MARK: - Clipboard Support

    /// Intercept standard clipboard shortcuts so they reach WebKit's internal
    /// handling instead of being swallowed by the SwiftUI menu bar responder chain.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown,
           event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           let chars = event.charactersIgnoringModifiers,
           ["c", "x", "a"].contains(chars) {
            switch chars {
            case "c":
                evaluateJavaScript("window.getSelection()?.toString() ?? ''") { result, _ in
                    if let text = result as? String, !text.isEmpty {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                }
                return true
            case "x":
                evaluateJavaScript("window.getSelection()?.toString() ?? ''") { result, _ in
                    if let text = result as? String, !text.isEmpty {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                }
                return true
            case "a":
                evaluateJavaScript("document.execCommand('selectAll')")
                return true
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }

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
    var rawMarkdown: String?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.userContentController.add(context.coordinator, name: "glossGuide")

        let webView = DropAcceptingWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.webView = webView
        DropAcceptingWebView.current = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let contentChanged = htmlContent != context.coordinator.lastHTML
        context.coordinator.pendingHighlight = highlightQuery
        (webView as? DropAcceptingWebView)?.rawMarkdown = rawMarkdown

        if contentChanged {
            context.coordinator.lastHTML = htmlContent
            webView.loadHTMLString(htmlContent, baseURL: baseURL)
            // highlight will be applied in didFinishNavigation
        } else if highlightQuery != context.coordinator.activeHighlight {
            // Content same but query changed — apply highlight now
            context.coordinator.applyHighlight(highlightQuery)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, @unchecked Sendable {
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
            // Dispatch a web guide step
            observers.append(
                NotificationCenter.default.addObserver(
                    forName: .glossGuideDispatchWeb, object: nil, queue: .main
                ) { [weak self] notification in
                    let step = notification.object as? WebStep
                    let current = notification.userInfo?["current"] as? Int ?? 1
                    let total = notification.userInfo?["total"] as? Int ?? 1
                    MainActor.assumeIsolated {
                        guard let step else { return }
                        self?.dispatchGuideStep(step, current: current, total: total)
                    }
                }
            )
            // Stop web guide
            observers.append(
                NotificationCenter.default.addObserver(
                    forName: .glossGuideStopWeb, object: nil, queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.webView?.evaluateJavaScript(
                            "window.glossGuide && window.glossGuide.stop()",
                            completionHandler: nil
                        )
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

        // MARK: - Guide Message Handler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "glossGuide" else { return }
            // Accept both String (JSON.stringify) and Dictionary (raw object) payloads
            let json: [String: Any]?
            if let body = message.body as? String,
               let data = body.data(using: .utf8) {
                json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            } else if let dict = message.body as? [String: Any] {
                json = dict
            } else {
                return
            }
            guard let json, let type = json["type"] as? String else { return }

            MainActor.assumeIsolated {
                switch type {
                case "ready":
                    NotificationCenter.default.post(name: .glossGuideReady, object: nil)
                case "complete":
                    NotificationCenter.default.post(name: .glossGuideStepComplete, object: nil)
                case "skip":
                    NotificationCenter.default.post(name: .glossGuideStopped, object: nil)
                default:
                    break
                }
            }
        }

        private func dispatchGuideStep(_ step: WebStep, current: Int, total: Int) {
            guard let jsonData = try? JSONSerialization.data(
                withJSONObject: step.jsonObject, options: []
            ), let jsonString = String(data: jsonData, encoding: .utf8) else {
                return
            }

            // Retry briefly if glossGuide isn't ready yet (SDK init may still be running)
            let js = """
            (function() {
                function dispatch() {
                    if (window.glossGuide) {
                        window.glossGuide.startStep(\(jsonString), \(current), \(total));
                    } else {
                        setTimeout(dispatch, 100);
                    }
                }
                dispatch();
            })()
            """
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        private func exportPDF() {
            guard let webView else { return }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = "document.pdf"
            panel.title = "Export as PDF"
            guard panel.runModal() == .OK, let saveURL = panel.url else { return }

            webView.createPDF { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let data):
                        do {
                            try data.write(to: saveURL)
                            self.showExportConfirmation(for: saveURL)
                        } catch {
                            // Write failed silently
                        }
                    case .failure:
                        break
                    }
                }
            }
        }

        private func showExportConfirmation(for url: URL) {
            let alert = NSAlert()
            alert.messageText = "PDF Exported"
            alert.informativeText = url.lastPathComponent
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open PDF")
            alert.addButton(withTitle: "Reveal in Finder")
            alert.addButton(withTitle: "OK")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                NSWorkspace.shared.open(url)
            case .alertSecondButtonReturn:
                NSWorkspace.shared.activateFileViewerSelecting([url])
            default:
                break
            }
        }

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

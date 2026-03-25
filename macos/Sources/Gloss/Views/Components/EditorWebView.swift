import SwiftUI
import WebKit

extension Notification.Name {
    static let glossEditorDirtyChanged = Notification.Name("glossEditorDirtyChanged")
    static let glossEditorSaved = Notification.Name("glossEditorSaved")
    static let glossToggleEditMode = Notification.Name("glossToggleEditMode")
}

/// WKWebView subclass for the CodeMirror 6 markdown editor.
@MainActor
class GlossEditorWebView: WKWebView {
    /// Shared reference for save operations from menu commands.
    static weak var current: GlossEditorWebView?

    var fileURL: URL?

    /// Get current editor content and write to disk.
    func saveCurrentContent(completion: ((Bool) -> Void)? = nil) {
        guard let fileURL else { completion?(false); return }
        evaluateJavaScript("glossEditor.getContent()") { result, error in
            DispatchQueue.main.async {
                guard let content = result as? String else {
                    completion?(false)
                    return
                }
                do {
                    try content.write(to: fileURL, atomically: true, encoding: .utf8)
                    self.evaluateJavaScript("glossEditor.markClean()", completionHandler: nil)
                    NotificationCenter.default.post(name: .glossEditorSaved, object: fileURL)
                    NotificationCenter.default.post(
                        name: .glossEditorDirtyChanged,
                        object: NSNumber(value: false)
                    )
                    completion?(true)
                } catch {
                    completion?(false)
                }
            }
        }
    }
}

/// NSViewRepresentable wrapper for CodeMirror 6 markdown editor in WKWebView.
struct EditorWebView: NSViewRepresentable {
    let fileURL: URL
    var isDark: Bool
    var fontSize: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        // Allow ES module imports from HTTPS CDNs when loaded from file:// origin
        config.preferences.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        config.userContentController.add(context.coordinator, name: "glossEditor")

        let webView = GlossEditorWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        webView.fileURL = fileURL
        context.coordinator.webView = webView
        GlossEditorWebView.current = webView

        loadTemplate(into: webView, context: context)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard let webView = nsView as? GlossEditorWebView else { return }

        if isDark != context.coordinator.lastIsDark {
            context.coordinator.lastIsDark = isDark
            webView.evaluateJavaScript(
                "glossEditor?.setTheme(\(isDark))",
                completionHandler: nil
            )
        }

        if fontSize != context.coordinator.lastFontSize {
            context.coordinator.lastFontSize = fontSize
            webView.evaluateJavaScript(
                "document.documentElement.style.setProperty('--font-size', '\(fontSize)px')",
                completionHandler: nil
            )
        }

        if fileURL != context.coordinator.lastFileURL {
            context.coordinator.lastFileURL = fileURL
            webView.fileURL = fileURL
            context.coordinator.loadFileContent()
        }
    }

    private func loadTemplate(into webView: WKWebView, context: Context) {
        let templateURL: URL?
        #if XCODE_BUILD
        templateURL = Bundle.main.url(forResource: "editor", withExtension: "html")
        #else
        templateURL = Bundle.module.url(forResource: "editor", withExtension: "html")
        #endif

        var html: String
        if let templateURL, let content = try? String(contentsOf: templateURL, encoding: .utf8) {
            html = content
        } else {
            html = "<html><body><p>Failed to load editor template</p></body></html>"
        }

        // Inject theme class
        html = html.replacingOccurrences(
            of: "<html lang=\"en\">",
            with: "<html lang=\"en\" class=\"\(isDark ? "dark" : "light")\">"
        )

        // Inject font size override
        if fontSize != 16 {
            html = html.replacingOccurrences(
                of: "/* FONT_SIZE_OVERRIDE */",
                with: ":root { --font-size: \(fontSize)px; }"
            )
        }

        context.coordinator.lastIsDark = isDark
        context.coordinator.lastFontSize = fontSize
        context.coordinator.lastFileURL = fileURL

        // Write to a temp file in the same directory as the document so that:
        // 1. loadFileURL gives a proper file:// origin (not null)
        // 2. ES module imports from CDN work (CORS needs a real origin)
        // 3. Relative image paths in markdown resolve correctly
        let dir = fileURL.deletingLastPathComponent()
        let tempFile = dir.appendingPathComponent(".gloss-editor-temp.html")
        do {
            try html.write(to: tempFile, atomically: true, encoding: .utf8)
            webView.loadFileURL(tempFile, allowingReadAccessTo: dir)
        } catch {
            // Fallback to loadHTMLString if write fails (e.g. read-only directory)
            webView.loadHTMLString(html, baseURL: dir)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, @unchecked Sendable {
        weak var webView: GlossEditorWebView?
        var lastIsDark = false
        var lastFontSize = 16
        var lastFileURL: URL?
        var isReady = false

        // MARK: - WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "glossEditor",
                  let body = message.body as? String,
                  let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { return }

            MainActor.assumeIsolated {
                switch type {
                case "ready":
                    isReady = true
                    loadFileContent()
                case "save":
                    webView?.saveCurrentContent()
                case "dirty":
                    let dirty = json["isDirty"] as? Bool ?? false
                    NotificationCenter.default.post(
                        name: .glossEditorDirtyChanged,
                        object: NSNumber(value: dirty)
                    )
                default:
                    break
                }
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // ES modules load asynchronously — content loaded when "ready" message arrives
        }

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

            // External URLs — open in browser
            if url.scheme == "http" || url.scheme == "https" {
                MainActor.assumeIsolated { _ = NSWorkspace.shared.open(url) }
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        // MARK: - Content

        func loadFileContent() {
            guard isReady, let url = lastFileURL else { return }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }

            // JSON-encode for safe JS string injection
            guard let jsonData = try? JSONEncoder().encode(content),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }

            webView?.evaluateJavaScript(
                "glossEditor.setContent(\(jsonString))",
                completionHandler: nil
            )
        }
    }
}

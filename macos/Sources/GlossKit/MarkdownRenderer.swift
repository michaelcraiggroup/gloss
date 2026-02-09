import Foundation
import Markdown

/// Converts markdown source text into a full HTML document with Gloss theming.
/// Shared library used by both the Gloss app and Quick Look extension.
public struct MarkdownRenderer: Sendable {

    /// Render markdown source into a complete HTML document.
    /// - Parameters:
    ///   - source: Raw markdown text
    ///   - isDark: Whether to apply dark theme class. When nil, omits html class
    ///     so `prefers-color-scheme` CSS media query drives appearance (used by Quick Look).
    ///   - fontSize: Base font size in pixels (default 16).
    /// - Returns: Full HTML document string
    public static func render(_ source: String, isDark: Bool? = nil, fontSize: Int = 16) -> String {
        let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        let bodyHTML = HTMLFormatter.format(document)
        return wrapInDocument(bodyHTML, isDark: isDark, fontSize: fontSize)
    }

    /// Wrap HTML body content in a full document with CSS theme.
    private static func wrapInDocument(_ bodyHTML: String, isDark: Bool?, fontSize: Int) -> String {
        let themeClassAttr: String
        if let isDark {
            themeClassAttr = " class=\"\(isDark ? "dark" : "light")\""
        } else {
            themeClassAttr = ""
        }
        let css = loadCSS()
        let fontSizeOverride = fontSize != 16 ? "\n            <style>:root { --font-size: \(fontSize)px; }</style>" : ""

        return """
        <!DOCTYPE html>
        <html lang="en"\(themeClassAttr)>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>\(css)</style>\(fontSizeOverride)
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css" media="(prefers-color-scheme: dark)">
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" media="(prefers-color-scheme: light)">
        </head>
        <body>
            <div class="gloss-content">
                \(bodyHTML)
            </div>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
            <script>hljs.highlightAll();</script>
            \(copyButtonScript)
            \(keyboardNavScript)
        </body>
        </html>
        """
    }

    /// JavaScript to add copy buttons to all code blocks.
    private static let copyButtonScript = """
    <script>
    document.querySelectorAll('pre').forEach(function(pre) {
        var btn = document.createElement('button');
        btn.className = 'copy-btn';
        btn.textContent = 'Copy';
        btn.addEventListener('click', function() {
            var code = pre.querySelector('code');
            var text = code ? code.textContent : pre.textContent;
            navigator.clipboard.writeText(text).then(function() {
                btn.textContent = 'Copied!';
                setTimeout(function() { btn.textContent = 'Copy'; }, 2000);
            });
        });
        pre.appendChild(btn);
    });
    </script>
    """

    /// JavaScript for vim-style keyboard navigation.
    private static let keyboardNavScript = """
    <script>
    (function() {
        var pending = '';
        document.addEventListener('keydown', function(e) {
            if (e.metaKey || e.ctrlKey || e.altKey) return;
            var key = e.key;
            if (key === 'j') {
                e.preventDefault();
                window.scrollBy({ top: 100, behavior: 'smooth' });
                pending = '';
            } else if (key === 'k') {
                e.preventDefault();
                window.scrollBy({ top: -100, behavior: 'smooth' });
                pending = '';
            } else if (key === 'G' && !e.shiftKey === false) {
                e.preventDefault();
                window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });
                pending = '';
            } else if (key === 'g') {
                if (pending === 'g') {
                    e.preventDefault();
                    window.scrollTo({ top: 0, behavior: 'smooth' });
                    pending = '';
                } else {
                    pending = 'g';
                    setTimeout(function() { pending = ''; }, 500);
                }
            } else if (key === ' ') {
                e.preventDefault();
                var delta = e.shiftKey ? -window.innerHeight * 0.8 : window.innerHeight * 0.8;
                window.scrollBy({ top: delta, behavior: 'smooth' });
                pending = '';
            } else {
                pending = '';
            }
        });
    })();
    </script>
    """

    /// Load the CSS theme from the bundled resource.
    private static func loadCSS() -> String {
        guard let url = Bundle.module.url(forResource: "gloss-theme", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            return "/* Failed to load theme CSS */"
        }
        return css
    }
}

import Foundation
import Markdown

/// Converts markdown source text into a full HTML document with Gloss theming.
struct MarkdownRenderer {

    /// Render markdown source into a complete HTML document.
    /// - Parameters:
    ///   - source: Raw markdown text
    ///   - isDark: Whether to apply dark theme class
    /// - Returns: Full HTML document string
    static func render(_ source: String, isDark: Bool) -> String {
        let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        let bodyHTML = HTMLFormatter.format(document)
        return wrapInDocument(bodyHTML, isDark: isDark)
    }

    /// Wrap HTML body content in a full document with CSS theme.
    private static func wrapInDocument(_ bodyHTML: String, isDark: Bool) -> String {
        let themeClass = isDark ? "dark" : "light"
        let css = loadCSS()

        return """
        <!DOCTYPE html>
        <html lang="en" class="\(themeClass)">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>\(css)</style>
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css" media="(prefers-color-scheme: dark)">
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" media="(prefers-color-scheme: light)">
        </head>
        <body>
            <div class="gloss-content">
                \(bodyHTML)
            </div>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
            <script>hljs.highlightAll();</script>
        </body>
        </html>
        """
    }

    /// Load the CSS theme from the bundled resource.
    private static func loadCSS() -> String {
        guard let url = Bundle.module.url(forResource: "gloss-theme", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            return "/* Failed to load theme CSS */"
        }
        return css
    }
}

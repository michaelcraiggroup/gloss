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
            \(findInPageScript)
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
            if (document.activeElement && document.activeElement.tagName === 'INPUT') return;
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

    /// JavaScript for find-in-page search bar.
    private static let findInPageScript = """
    <script>
    (function() {
        var bar = document.createElement('div');
        bar.className = 'gloss-find-bar';
        bar.hidden = true;
        bar.innerHTML = '<input type="text" placeholder="Find…" spellcheck="false" autocomplete="off">' +
            '<span class="gloss-find-count"></span>' +
            '<button class="gloss-find-prev" title="Previous (⌘⇧G)">▲</button>' +
            '<button class="gloss-find-next" title="Next (⌘G)">▼</button>' +
            '<button class="gloss-find-close" title="Close (Esc)">✕</button>';
        document.body.appendChild(bar);

        var input = bar.querySelector('input');
        var countEl = bar.querySelector('.gloss-find-count');
        var matches = [];
        var currentIndex = -1;

        bar.querySelector('.gloss-find-prev').addEventListener('click', function() { navigateMatch(-1); });
        bar.querySelector('.gloss-find-next').addEventListener('click', function() { navigateMatch(1); });
        bar.querySelector('.gloss-find-close').addEventListener('click', function() { closeFindBar(); });

        input.addEventListener('input', function() {
            performFind(input.value);
        });

        input.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                navigateMatch(e.shiftKey ? -1 : 1);
            } else if (e.key === 'Escape') {
                e.preventDefault();
                closeFindBar();
            }
        });

        function toggleFindBar() {
            if (bar.hidden) {
                bar.hidden = false;
                input.focus();
                input.select();
            } else {
                closeFindBar();
            }
        }

        function closeFindBar() {
            bar.hidden = true;
            clearHighlights();
            input.value = '';
            countEl.textContent = '';
        }

        function clearHighlights() {
            matches = [];
            currentIndex = -1;
            var marks = document.querySelectorAll('.gloss-find-match');
            for (var i = 0; i < marks.length; i++) {
                var mark = marks[i];
                var parent = mark.parentNode;
                parent.replaceChild(document.createTextNode(mark.textContent), mark);
                parent.normalize();
            }
        }

        function performFind(query) {
            clearHighlights();
            if (!query) { countEl.textContent = ''; return; }
            var content = document.querySelector('.gloss-content');
            if (!content) return;
            var walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, null);
            var textNodes = [];
            while (walker.nextNode()) textNodes.push(walker.currentNode);
            var lowerQuery = query.toLowerCase();
            for (var i = 0; i < textNodes.length; i++) {
                var node = textNodes[i];
                var text = node.textContent;
                var lowerText = text.toLowerCase();
                var idx = lowerText.indexOf(lowerQuery);
                if (idx === -1) continue;
                var parts = [];
                var lastIdx = 0;
                while (idx !== -1) {
                    if (idx > lastIdx) parts.push(document.createTextNode(text.substring(lastIdx, idx)));
                    var mark = document.createElement('mark');
                    mark.className = 'gloss-find-match';
                    mark.textContent = text.substring(idx, idx + query.length);
                    parts.push(mark);
                    lastIdx = idx + query.length;
                    idx = lowerText.indexOf(lowerQuery, lastIdx);
                }
                if (lastIdx < text.length) parts.push(document.createTextNode(text.substring(lastIdx)));
                var parent = node.parentNode;
                for (var j = 0; j < parts.length; j++) parent.insertBefore(parts[j], node);
                parent.removeChild(node);
            }
            matches = Array.from(document.querySelectorAll('.gloss-find-match'));
            if (matches.length > 0) {
                currentIndex = 0;
                matches[0].classList.add('gloss-find-current');
                matches[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
                countEl.textContent = '1 / ' + matches.length;
            } else {
                countEl.textContent = 'No matches';
            }
        }

        function navigateMatch(delta) {
            if (matches.length === 0) return;
            matches[currentIndex].classList.remove('gloss-find-current');
            currentIndex = (currentIndex + delta + matches.length) % matches.length;
            matches[currentIndex].classList.add('gloss-find-current');
            matches[currentIndex].scrollIntoView({ behavior: 'smooth', block: 'center' });
            countEl.textContent = (currentIndex + 1) + ' / ' + matches.length;
        }

        document.addEventListener('keydown', function(e) {
            if (e.metaKey && e.key === 'f') {
                e.preventDefault();
                toggleFindBar();
            } else if (e.metaKey && e.key === 'g') {
                e.preventDefault();
                if (!bar.hidden) navigateMatch(e.shiftKey ? -1 : 1);
            }
        });

        // Expose for external evaluation (menu commands)
        window.glossToggleFindBar = toggleFindBar;
        window.glossFindNext = function() { navigateMatch(1); };
        window.glossFindPrevious = function() { navigateMatch(-1); };
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

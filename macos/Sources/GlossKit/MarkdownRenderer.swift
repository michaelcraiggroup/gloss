import Foundation
import Markdown
import Yams

/// A heading extracted from a markdown document, with its level, text, and generated anchor ID.
public struct HeadingInfo: Sendable, Equatable {
    public let level: Int
    public let text: String
    public let id: String
}

/// A wiki-link extracted from markdown source, with target, type, display text, and line number.
public struct ExtractedLink: Sendable, Equatable {
    public let target: String
    public let linkType: String
    public let displayText: String?
    public let lineNumber: Int
}

/// Parsed frontmatter data from a markdown document.
public struct FrontmatterData: Sendable, Equatable {
    public let raw: String
    public let fields: [(key: String, value: String)]

    public static func == (lhs: FrontmatterData, rhs: FrontmatterData) -> Bool {
        lhs.raw == rhs.raw
    }
}

/// Converts markdown source text into a full HTML document with Gloss theming.
/// Shared library used by both the Gloss app and Quick Look extension.
public struct MarkdownRenderer: Sendable {

    /// Render markdown source into a complete HTML document.
    /// - Parameters:
    ///   - source: Raw markdown text
    ///   - isDark: Whether to apply dark theme class. When nil, omits html class
    ///     so `prefers-color-scheme` CSS media query drives appearance (used by Quick Look).
    ///   - fontSize: Base font size in pixels (default 16).
    ///   - resolveWikiLink: Optional closure to resolve `[[wiki-link]]` targets to file paths.
    /// - Returns: Full HTML document string
    public static func render(
        _ source: String,
        isDark: Bool? = nil,
        fontSize: Int = 16,
        resolveWikiLink: ((String) -> String?)? = nil
    ) -> String {
        let stripped = stripFrontmatter(source)
        let mdPlus = MdPlusParser.parse(stripped)
        let preprocessed = resolveWikiLink != nil
            ? preprocessWikiLinks(mdPlus.processedSource, resolver: resolveWikiLink!)
            : mdPlus.processedSource
        let document = Document(parsing: preprocessed, options: [.parseBlockDirectives, .parseSymbolLinks])
        var bodyHTML = HTMLFormatter.format(document)
        bodyHTML = escapeCodeContent(bodyHTML)
        bodyHTML = addHeadingIDs(bodyHTML)
        bodyHTML = processTaskCheckboxes(bodyHTML)
        let hasMermaid = source.contains("```mermaid")
        let hasMath = source.contains("$$") || source.contains("$\\")
            || source.contains("\\(") || source.contains("\\[")
        let hasFillable = MdPlusParser.hasFillableContent(stripped) || !mdPlus.blocks.isEmpty
        return wrapInDocument(
            bodyHTML,
            isDark: isDark,
            fontSize: fontSize,
            hasMermaid: hasMermaid,
            hasMath: hasMath,
            hasFillable: hasFillable
        )
    }

    /// Whether this source contains interactive content (GFM task lists or
    /// md+ template blocks) that should enable the "Save Filled Copy" flow.
    public static func hasFillableContent(_ source: String) -> Bool {
        MdPlusParser.hasFillableContent(stripFrontmatter(source))
    }

    /// Extract headings from markdown source for TOC generation.
    public static func extractHeadings(_ source: String) -> [HeadingInfo] {
        let stripped = stripFrontmatter(source)
        let document = Document(parsing: stripped, options: [.parseBlockDirectives, .parseSymbolLinks])
        var headings: [HeadingInfo] = []
        var slugCounts: [String: Int] = [:]
        for child in document.children {
            if let heading = child as? Heading {
                let text = heading.plainText
                let baseSlug = generateSlug(text)
                let count = slugCounts[baseSlug, default: 0]
                let slug = count == 0 ? baseSlug : "\(baseSlug)-\(count)"
                slugCounts[baseSlug] = count + 1
                headings.append(HeadingInfo(level: heading.level, text: text, id: slug))
            }
        }
        return headings
    }

    /// Parse frontmatter YAML from a markdown document.
    public static func extractFrontmatter(_ source: String) -> FrontmatterData? {
        guard let raw = extractRawFrontmatter(source) else { return nil }
        guard let parsed = try? Yams.load(yaml: raw), let dict = parsed as? [String: Any] else {
            return FrontmatterData(raw: raw, fields: [])
        }
        let fields: [(key: String, value: String)] = dict.sorted(by: { $0.key < $1.key }).map { key, value in
            (key: key, value: formatYamlValue(value))
        }
        return FrontmatterData(raw: raw, fields: fields)
    }

    /// Extract the raw YAML frontmatter string (without delimiters).
    static func extractRawFrontmatter(_ source: String) -> String? {
        guard source.hasPrefix("---\n") || source.hasPrefix("---\r\n") else { return nil }
        let startIndex = source.index(source.startIndex, offsetBy: 3)
        let rest = source[startIndex...]
        guard let closingRange = rest.range(of: "\n---\n") ?? rest.range(of: "\r\n---\r\n") ?? rest.range(of: "\n---") else {
            return nil
        }
        let yaml = rest[rest.startIndex..<closingRange.lowerBound]
        let trimmed = yaml.trimmingCharacters(in: .newlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Format a YAML value for display.
    private static func formatYamlValue(_ value: Any) -> String {
        switch value {
        case let array as [Any]:
            return array.map { formatYamlValue($0) }.joined(separator: ", ")
        case let dict as [String: Any]:
            return dict.map { "\($0.key): \(formatYamlValue($0.value))" }.joined(separator: ", ")
        default:
            return String(describing: value)
        }
    }

    /// Strip YAML frontmatter (content between leading `---` delimiters).
    static func stripFrontmatter(_ source: String) -> String {
        guard source.hasPrefix("---\n") || source.hasPrefix("---\r\n") else {
            return source
        }
        // Find the closing --- after the opening one
        let startIndex = source.index(source.startIndex, offsetBy: 3) // skip "---"
        let rest = source[startIndex...]
        guard let closingRange = rest.range(of: "\n---\n") ?? rest.range(of: "\r\n---\r\n") ?? rest.range(of: "\n---") else {
            return source // no closing delimiter, leave as-is
        }
        // Check if closing delimiter is at end of string (no trailing newline)
        if closingRange.upperBound == source.endIndex {
            return ""
        }
        return String(source[closingRange.upperBound...])
    }

    // MARK: - Task Checkboxes (GFM)

    /// Post-process HTML to make GFM task-list checkboxes interactive.
    /// swift-markdown emits `<input type="checkbox" disabled="">` for task
    /// list items; this strips `disabled=""` and adds a sequential
    /// `data-gloss-task-index="N"` attribute so the Save Filled Copy flow
    /// can correlate DOM state back to source line positions.
    static func processTaskCheckboxes(_ html: String) -> String {
        let pattern = #"<input type="checkbox"\s+disabled=""([^>]*)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let nsHtml = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))
        guard !matches.isEmpty else { return html }
        var result = html
        // Reverse-iterate so ranges remain valid; capture the original index.
        for (i, match) in matches.enumerated().reversed() {
            guard let fullRange = Range(match.range, in: result) else { continue }
            let original = String(result[fullRange])
            var replacement = original.replacingOccurrences(
                of: #"\s*disabled=""\s*"#,
                with: " ",
                options: .regularExpression
            )
            // Insert data-gloss-task-index before the closing `>` (or `/>`)
            if let gt = replacement.lastIndex(of: ">") {
                let insertPoint: String.Index
                if replacement.distance(from: replacement.startIndex, to: gt) > 0,
                   replacement[replacement.index(before: gt)] == "/" {
                    insertPoint = replacement.index(before: gt)
                } else {
                    insertPoint = gt
                }
                replacement.insert(contentsOf: " data-gloss-task-index=\"\(i)\"", at: insertPoint)
            }
            result.replaceSubrange(fullRange, with: replacement)
        }
        // Tag parent <li> with a class so the task-list CSS can target it
        // directly. Avoids the `:has()` selector (expensive in WebKit —
        // causes per-keystroke style recalc when descendants change).
        result = result.replacingOccurrences(
            of: #"<li>(\s*)<input type="checkbox""#,
            with: #"<li class="gloss-task-item">$1<input type="checkbox""#,
            options: .regularExpression
        )
        return result
    }

    // MARK: - Code Content Escaping

    /// Escape HTML entities inside `<code>` tags. swift-markdown's HTMLFormatter
    /// does not escape angle brackets in InlineCode or CodeBlock nodes.
    static func escapeCodeContent(_ html: String) -> String {
        let pattern = #"<code(?:\s[^>]*)?>(.+?)</code>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else {
            return html
        }
        var result = html
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let contentRange = Range(match.range(at: 1), in: result) else { continue }
            let content = String(result[contentRange])
            // Only process if there are unescaped angle brackets
            guard content.contains("<") || content.contains(">") else { continue }
            let escaped = content
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            result.replaceSubrange(contentRange, with: escaped)
        }
        return result
    }

    // MARK: - Heading IDs

    /// Generate a URL-friendly slug from heading text.
    static func generateSlug(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }
            .reduce(into: "") { $0.append(String($1)) }
    }

    /// Post-process HTML to add `id` attributes to heading tags.
    static func addHeadingIDs(_ html: String) -> String {
        var result = html
        var slugCounts: [String: Int] = [:]
        let pattern = #"<(h[1-6])>(.*?)</h[1-6]>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else {
            return html
        }
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        // Process in reverse to preserve ranges
        for match in matches.reversed() {
            guard let tagRange = Range(match.range(at: 1), in: result),
                  let contentRange = Range(match.range(at: 2), in: result),
                  let fullRange = Range(match.range, in: result) else { continue }
            let tag = String(result[tagRange])
            let content = String(result[contentRange])
            let plainText = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
            let baseSlug = generateSlug(plainText)
            let count = slugCounts[baseSlug, default: 0]
            let slug = count == 0 ? baseSlug : "\(baseSlug)-\(count)"
            slugCounts[baseSlug] = count + 1
            let replacement = "<\(tag) id=\"\(slug)\">\(content)</\(tag)>"
            result.replaceSubrange(fullRange, with: replacement)
        }
        return result
    }

    // MARK: - Wiki-Links

    /// Parse the inner content of a wiki-link into (target, type, display).
    /// Supports: `[[target]]`, `[[target|display]]`, `[[target::type]]`, `[[target::type|display]]`
    public static func parseWikiLinkInner(_ inner: String) -> (target: String, linkType: String, display: String?) {
        let parts = inner.split(separator: "|", maxSplits: 1)
        let leftSide = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let displayText = parts.count > 1
            ? String(parts[1]).trimmingCharacters(in: .whitespaces)
            : nil

        let typeParts = leftSide.split(separator: "::", maxSplits: 1)
        let target = String(typeParts[0]).trimmingCharacters(in: .whitespaces)
        let linkType = typeParts.count > 1
            ? String(typeParts[1]).trimmingCharacters(in: .whitespaces).lowercased()
            : "related"

        return (target, linkType, displayText)
    }

    /// Pre-process wiki-links `[[target]]`, `[[target|display]]`, `[[target::type]]`,
    /// and `[[target::type|display]]` into standard markdown links.
    static func preprocessWikiLinks(_ source: String, resolver: (String) -> String?) -> String {
        let pattern = #"\[\[([^\]]+)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return source }
        var result = source
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let innerRange = Range(match.range(at: 1), in: result) else { continue }
            let inner = String(result[innerRange])
            let parsed = parseWikiLinkInner(inner)
            let display = parsed.display ?? parsed.target
            if let resolved = resolver(parsed.target) {
                let link = "[\(display)](\(resolved))"
                result.replaceSubrange(fullRange, with: link)
            } else {
                // Unresolved — render as styled span
                let span = "[\(display)](#)"
                result.replaceSubrange(fullRange, with: span)
            }
        }
        return result
    }

    // MARK: - Link & Tag Extraction

    /// Extract all wiki-links from markdown source, with target, type, display text, and line number.
    public static func extractLinks(_ source: String) -> [ExtractedLink] {
        let pattern = #"\[\[([^\]]+)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let lines = source.components(separatedBy: .newlines)
        var links: [ExtractedLink] = []

        for (lineIndex, line) in lines.enumerated() {
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            for match in matches {
                guard let innerRange = Range(match.range(at: 1), in: line) else { continue }
                let inner = String(line[innerRange])
                let parsed = parseWikiLinkInner(inner)
                links.append(ExtractedLink(
                    target: parsed.target,
                    linkType: parsed.linkType,
                    displayText: parsed.display,
                    lineNumber: lineIndex + 1
                ))
            }
        }
        return links
    }

    /// Extract tags from YAML frontmatter. Supports both list and comma-separated formats.
    public static func extractTags(_ source: String) -> [String] {
        guard let raw = extractRawFrontmatter(source) else { return [] }
        guard let parsed = try? Yams.load(yaml: raw), let dict = parsed as? [String: Any] else { return [] }
        guard let tagsValue = dict["tags"] else { return [] }

        if let tagArray = tagsValue as? [Any] {
            return tagArray.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        if let tagString = tagsValue as? String {
            return tagString.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        return []
    }

    /// Wrap HTML body content in a full document with CSS theme.
    private static func wrapInDocument(_ bodyHTML: String, isDark: Bool?, fontSize: Int, hasMermaid: Bool = false, hasMath: Bool = false, hasFillable: Bool = false) -> String {
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
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" media="(prefers-color-scheme: light)">\(hasMath ? "\n            <link rel=\"stylesheet\" href=\"https://cdnjs.cloudflare.com/ajax/libs/KaTeX/0.16.9/katex.min.css\">" : "")
        </head>
        <body>
            <div class="gloss-content">
                \(bodyHTML)
            </div>
            <script>
            // Load hljs asynchronously so it doesn't block page interactivity.
            // Synchronous <script src=...> here blocks all JS until the CDN
            // responds, which also blocks click/focus events on form fields.
            (function() {
                var s = document.createElement('script');
                s.src = 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js';
                s.async = true;
                s.onload = function() {
                    document.querySelectorAll('pre code').forEach(function(block) {
                        if (!block.classList.contains('language-mermaid')) {
                            hljs.highlightElement(block);
                        }
                    });
                };
                document.head.appendChild(s);
            })();
            </script>
            \(copyButtonScript)
            \(headingAnchorScript)
            \(hasMermaid ? mermaidScript : "")
            \(hasMath ? katexScript : "")
            \(hasFillable ? templateFillStyle : "")
            \(hasFillable ? templateFillScript : "")
            \(virtualizationScript)
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
        if (pre.classList.contains('mermaid')) return;
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

    /// JavaScript to add anchor links to headings with IDs.
    private static let headingAnchorScript = """
    <script>
    document.querySelectorAll('h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]').forEach(function(h) {
        var a = document.createElement('a');
        a.className = 'heading-anchor';
        a.href = '#' + h.id;
        a.textContent = '#';
        a.setAttribute('aria-hidden', 'true');
        h.prepend(a);
    });
    </script>
    """

    /// Mermaid diagram rendering — CDN script + initialization.
    private static let mermaidScript = """
    <script src="https://cdnjs.cloudflare.com/ajax/libs/mermaid/11.12.0/mermaid.min.js"></script>
    <script>
    (async function() {
        if (typeof mermaid === 'undefined') return;
        var htmlEl = document.documentElement;
        var isDark = false;
        if (htmlEl.classList.contains('dark')) {
            isDark = true;
        } else if (!htmlEl.classList.contains('light')) {
            isDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
        }
        mermaid.initialize({ startOnLoad: false, theme: isDark ? 'dark' : 'default' });
        document.querySelectorAll('pre code.language-mermaid').forEach(function(code) {
            var pre = code.parentElement;
            var text = code.textContent;
            pre.className = 'mermaid';
            pre.textContent = text;
        });
        await mermaid.run();
    })();
    </script>
    """

    /// KaTeX math rendering — CDN scripts + auto-render initialization.
    private static let katexScript = """
    <script src="https://cdnjs.cloudflare.com/ajax/libs/KaTeX/0.16.9/katex.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/KaTeX/0.16.9/contrib/auto-render.min.js"></script>
    <script>
    (function() {
        function doRender() {
            if (typeof renderMathInElement === 'undefined') return false;
            renderMathInElement(document.querySelector('.gloss-content'), {
                delimiters: [
                    {left: '$$', right: '$$', display: true},
                    {left: '$', right: '$', display: false},
                    {left: '\\\\(', right: '\\\\)', display: false},
                    {left: '\\\\[', right: '\\\\]', display: true}
                ],
                throwOnError: false
            });
            return true;
        }
        if (!doRender()) {
            window.addEventListener('load', doRender);
        }
    })();
    </script>
    """

    /// Inline CSS for md+ template fieldsets and task-list checkbox polish.
    /// Scoped here (not in gloss-theme.css) so it only loads when the page
    /// actually has fillable content.
    private static let templateFillStyle = """
    <style>
    .gloss-content input[type="checkbox"][data-gloss-task-index] {
        cursor: pointer;
        width: 1em;
        height: 1em;
        vertical-align: middle;
        margin-right: 0.4em;
        accent-color: var(--accent);
    }
    .gloss-content ul li.gloss-task-item {
        list-style: none;
        margin-left: -1.5em;
    }
    .gloss-content .gloss-mdplus {
        border: 1px solid var(--border);
        border-radius: 8px;
        padding: 1em 1.25em;
        margin: 1.5em 0;
        background: var(--code-bg);
        /* Isolate layout/paint so typing in a field doesn't reflow the
           rest of the document (major WKWebView typing-lag cause). */
        contain: layout style;
    }
    .gloss-content .gloss-mdplus legend {
        padding: 0 0.5em;
        font-weight: 600;
        color: var(--accent);
    }
    .gloss-content .gloss-mdplus-field {
        display: flex;
        flex-direction: column;
        gap: 0.35em;
        margin-bottom: 0.85em;
    }
    .gloss-content .gloss-mdplus-field:last-child { margin-bottom: 0; }
    .gloss-content .gloss-mdplus-field label {
        font-size: 0.85em;
        font-weight: 500;
        color: var(--fg);
        opacity: 0.8;
    }
    .gloss-content .gloss-mdplus-field input[type="text"],
    .gloss-content .gloss-mdplus-field input[type="number"],
    .gloss-content .gloss-mdplus-field input[type="date"],
    .gloss-content .gloss-mdplus-field textarea,
    .gloss-content .gloss-mdplus-field select {
        font: inherit;
        color: var(--fg);
        background: var(--bg);
        border: 1px solid var(--border);
        border-radius: 4px;
        padding: 0.4em 0.6em;
    }
    .gloss-content .gloss-mdplus-field textarea { resize: vertical; }
    .gloss-content .gloss-mdplus-error {
        border: 1px solid #e11d48;
        border-radius: 8px;
        padding: 0.75em 1em;
        margin: 1.5em 0;
        background: rgba(225, 29, 72, 0.08);
    }
    .gloss-content .gloss-mdplus-error strong { color: #e11d48; }
    .gloss-content .gloss-mdplus-error pre { margin-top: 0.5em; }
    </style>
    """

    /// JavaScript bridge that exposes `window.glossTemplate.collectState()`
    /// to Swift. Called via `evaluateJavaScript` when the user invokes the
    /// "Save Filled Copy…" menu command; posts the collected checkbox and
    /// form field state to the `glossTemplate` script message handler.
    private static let templateFillScript = """
    <script>
    (function() {
        window.glossTemplate = {
            collectState: function() {
                var checkboxes = [];
                document.querySelectorAll('input[type="checkbox"][data-gloss-task-index]').forEach(function(el) {
                    checkboxes.push({
                        index: parseInt(el.dataset.glossTaskIndex, 10),
                        checked: !!el.checked
                    });
                });
                var fields = [];
                document.querySelectorAll('[data-gloss-mdplus-field]').forEach(function(el) {
                    var value;
                    if (el.type === 'checkbox') {
                        value = el.checked ? 'true' : 'false';
                    } else {
                        value = el.value;
                    }
                    fields.push({
                        blockId: el.dataset.glossMdplusBlock,
                        fieldName: el.dataset.glossMdplusField,
                        value: value
                    });
                });
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.glossTemplate) {
                    window.webkit.messageHandlers.glossTemplate.postMessage({
                        kind: 'filled',
                        checkboxes: checkboxes,
                        fields: fields
                    });
                }
            }
        };
    })();
    </script>
    """

    /// JavaScript for content-visibility virtualization on large documents.
    /// Fires after first paint to measure real block heights, then keeps a
    /// large pre-render zone (10× viewport height) visible on each side.
    /// Skipped entirely on small documents.
    private static let virtualizationScript = """
    <script>
    (function glossVirtualize() {
        // Pre-render zone: 10× viewport height on each side (~9000px on a
        // 900px display). Covers fast trackpad momentum scrolling.
        var MARGIN = Math.max(window.innerHeight * 10, 6000);
        var MIN_BLOCKS = 40; // don't bother on small docs

        function init() {
            var blocks = Array.from(
                document.querySelectorAll('.gloss-content > *')
            );
            if (blocks.length < MIN_BLOCKS) return;

            // Measure real rendered heights while all blocks are still fully
            // visible. Stores accurate intrinsic sizes so the scrollbar stays
            // stable after virtualization kicks in.
            var scrollY = window.scrollY;
            var vph = window.innerHeight;
            blocks.forEach(function(el) {
                var h = Math.max(el.getBoundingClientRect().height, 32);
                el.style.containIntrinsicBlockSize = h + 'px';

                // Pre-warm: synchronously mark every block inside the margin
                // as visible before the async observer fires, so there is no
                // single-frame gap where a block has content-visibility: auto
                // but the observer hasn't run yet.
                var top = scrollY + el.getBoundingClientRect().top;
                if (top >= scrollY - MARGIN && top <= scrollY + vph + MARGIN) {
                    el.style.contentVisibility = 'visible';
                }
            });

            // IntersectionObserver maintains the pre-render zone as the user
            // scrolls. rootMargin expands the intersection check by MARGIN px
            // in each direction so blocks become visible well before they reach
            // the actual viewport edge.
            var observer = new IntersectionObserver(function(entries) {
                entries.forEach(function(e) {
                    e.target.style.contentVisibility =
                        e.isIntersecting ? 'visible' : 'auto';
                });
            }, { rootMargin: MARGIN + 'px 0px', threshold: 0 });

            blocks.forEach(function(el) { observer.observe(el); });
        }

        // Two rAF hops guarantee layout is complete before we measure heights.
        requestAnimationFrame(function() { requestAnimationFrame(init); });
    })();
    </script>
    """

    /// JavaScript for vim-style keyboard navigation.
    private static let keyboardNavScript = """
    <script>
    (function() {
        var pending = '';
        document.addEventListener('keydown', function(e) {
            var el = document.activeElement;
            if (el) {
                var tag = el.tagName;
                if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;
                if (el.isContentEditable) return;
            }
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

        // Expose for external evaluation (menu commands + content search)
        window.glossToggleFindBar = toggleFindBar;
        window.glossFindNext = function() { navigateMatch(1); };
        window.glossFindPrevious = function() { navigateMatch(-1); };
        window.performFind = performFind;
        window.clearHighlights = clearHighlights;
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

import Testing
@testable import GlossKit

@Suite("KaTeX Math Rendering")
struct KaTeXTests {

    @Test("KaTeX CDN included when source has $$ display math")
    func katexCDNForDisplayMath() {
        let source = """
        # Math

        $$E = mc^2$$
        """
        let html = MarkdownRenderer.render(source)
        #expect(html.contains("KaTeX/0.16.9/katex.min.js"))
        #expect(html.contains("KaTeX/0.16.9/contrib/auto-render.min.js"))
    }

    @Test("KaTeX CDN included when source has $\\command$ inline math")
    func katexCDNForInlineMath() {
        let source = "The value is $\\alpha + \\beta$."
        let html = MarkdownRenderer.render(source)
        #expect(html.contains("KaTeX/0.16.9/katex.min.js"))
    }

    @Test("KaTeX CDN included when source has \\( delimiter")
    func katexCDNForParenDelimiter() {
        let source = "Inline math: \\(x^2\\)"
        let html = MarkdownRenderer.render(source)
        #expect(html.contains("KaTeX/0.16.9/katex.min.js"))
    }

    @Test("KaTeX CDN included when source has \\[ delimiter")
    func katexCDNForBracketDelimiter() {
        let source = "Display math: \\[\\int_0^1 x\\,dx\\]"
        let html = MarkdownRenderer.render(source)
        #expect(html.contains("KaTeX/0.16.9/katex.min.js"))
    }

    @Test("KaTeX CDN NOT included for plain text or currency")
    func katexCDNExcludedForCurrency() {
        let source = "The price is $10 and $20."
        let html = MarkdownRenderer.render(source)
        #expect(!html.contains("katex.min.js"))
    }

    @Test("Auto-render init script present with correct delimiters")
    func autoRenderInitScript() {
        let source = "$$x^2$$"
        let html = MarkdownRenderer.render(source)
        #expect(html.contains("renderMathInElement"))
        #expect(html.contains("display: true"))
        #expect(html.contains("display: false"))
    }

    @Test("Graceful offline fallback guard")
    func offlineFallback() {
        let source = "$$x$$"
        let html = MarkdownRenderer.render(source)
        #expect(html.contains("typeof renderMathInElement === 'undefined'"))
        #expect(html.contains("return false"))
    }

    @Test("KaTeX CSS link present when math detected")
    func katexCSSLink() {
        let source = "$$E = mc^2$$"
        let html = MarkdownRenderer.render(source)
        #expect(html.contains("KaTeX/0.16.9/katex.min.css"))
    }

    @Test("KaTeX CSS link absent when no math detected")
    func katexCSSLinkAbsent() {
        let source = "# Hello World"
        let html = MarkdownRenderer.render(source)
        #expect(!html.contains("katex.min.css"))
    }

    @Test("Color inheritance CSS present in theme")
    func colorInheritanceCSS() {
        let source = "$$x$$"
        let html = MarkdownRenderer.render(source)
        #expect(html.contains(".katex { color: inherit; }"))
    }

    @Test("Multi-line display math preserves $$ and backslash commands in HTML")
    func multiLineDisplayMath() {
        let source = """
        **Data Size Calculation:**
        $$
        \\text{bytes} = \\frac{\\text{integration time}}{\\text{waveform period}}
        \\times \\text{samples per waveform} \\times 2 \\text{ bytes}
        $$
        """
        let html = MarkdownRenderer.render(source)
        // $$ delimiters must be present as literal text for auto-render to match
        #expect(html.contains("$$"))
        // Backslash-commands must be preserved (not consumed by markdown parser)
        #expect(html.contains("\\frac"))
        #expect(html.contains("\\text"))
        #expect(html.contains("\\times"))
        // Must NOT be inside <pre> or <code> (auto-render ignores those)
        #expect(!html.contains("<code>$$"))
        #expect(!html.contains("<pre>$$"))
        // KaTeX scripts must be included
        #expect(html.contains("katex.min.js"))
    }

    @Test("Deferred load fallback for async script loading")
    func deferredLoadFallback() {
        let source = "$$x$$"
        let html = MarkdownRenderer.render(source)
        #expect(html.contains("window.addEventListener('load'"))
        #expect(html.contains("doRender"))
    }
}

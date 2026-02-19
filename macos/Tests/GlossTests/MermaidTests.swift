import Testing
@testable import GlossKit

@Suite("Mermaid Diagrams")
struct MermaidTests {

    @Test("Mermaid CDN included when source has mermaid block")
    func mermaidCDNIncluded() {
        let source = """
        # Diagram

        ```mermaid
        graph TD
            A --> B
        ```
        """
        let html = MarkdownRenderer.render(source)
        #expect(html.contains("mermaid/11.4.1/mermaid.min.js"))
    }

    @Test("Mermaid CDN NOT included when source has no mermaid block")
    func mermaidCDNExcluded() {
        let source = """
        # Hello

        ```swift
        let x = 42
        ```
        """
        let html = MarkdownRenderer.render(source)
        #expect(!html.contains("mermaid.min.js"))
    }

    @Test("hljs skips mermaid blocks")
    func hljsSkipsMermaid() {
        let html = MarkdownRenderer.render("```mermaid\ngraph TD\n```")
        #expect(html.contains("language-mermaid"))
        #expect(!html.contains("hljs.highlightAll()"))
    }

    @Test("Copy buttons skip mermaid containers")
    func copyButtonsSkipMermaid() {
        let html = MarkdownRenderer.render("```mermaid\ngraph TD\n```")
        #expect(html.contains("pre.classList.contains('mermaid')"))
    }

    @Test("Theme detection reads html class for dark mode")
    func themeDetectionDark() {
        let html = MarkdownRenderer.render("```mermaid\ngraph TD\n```", isDark: true)
        #expect(html.contains("htmlEl.classList.contains('dark')"))
    }

    @Test("Theme detection reads html class for light mode")
    func themeDetectionLight() {
        let html = MarkdownRenderer.render("```mermaid\ngraph TD\n```", isDark: false)
        #expect(html.contains("htmlEl.classList.contains('dark')"))
        #expect(html.contains("class=\"light\""))
    }

    @Test("Quick Look mode falls back to prefers-color-scheme")
    func quickLookFallback() {
        let html = MarkdownRenderer.render("```mermaid\ngraph TD\n```", isDark: nil)
        #expect(html.contains("matchMedia"))
        #expect(!html.contains("class=\"dark\""))
        #expect(!html.contains("class=\"light\""))
    }

    @Test("Graceful offline fallback guard")
    func offlineFallback() {
        let html = MarkdownRenderer.render("```mermaid\ngraph TD\n```")
        #expect(html.contains("typeof mermaid === 'undefined'"))
    }

    @Test("Mermaid CSS styles present in theme")
    func mermaidCSSPresent() {
        let html = MarkdownRenderer.render("```mermaid\ngraph TD\n```")
        #expect(html.contains("pre.mermaid"))
    }
}

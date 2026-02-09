import Testing
@testable import GlossKit

@Suite("GlossKit Integration")
struct GlossKitTests {

    @Test("Renders with nil isDark (Quick Look mode)")
    func quickLookMode() {
        let html = MarkdownRenderer.render("# Quick Look Test")
        // No explicit class on html element — prefers-color-scheme drives appearance
        #expect(html.contains("<html lang=\"en\">"))
        #expect(!html.contains("class=\"dark\""))
        #expect(!html.contains("class=\"light\""))
        #expect(html.contains("Quick Look Test"))
    }

    @Test("Quick Look mode still includes CSS theme")
    func quickLookIncludesCSS() {
        let html = MarkdownRenderer.render("test")
        #expect(html.contains("prefers-color-scheme: dark"))
        #expect(html.contains("--accent: #0d9488"))
    }

    @Test("Quick Look mode includes copy buttons and keyboard nav")
    func quickLookIncludesFeatures() {
        let html = MarkdownRenderer.render("```\ncode\n```")
        #expect(html.contains("copy-btn"))
        #expect(html.contains("addEventListener('keydown'"))
    }
}

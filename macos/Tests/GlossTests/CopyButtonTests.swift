import Testing
@testable import GlossKit

@Suite("Copy Button")
struct CopyButtonTests {

    @Test("Code block output contains copy-btn class")
    func codeBlockHasCopyButton() {
        let source = """
        ```swift
        let x = 42
        ```
        """
        let html = MarkdownRenderer.render(source, isDark: false)
        #expect(html.contains("copy-btn"))
    }

    @Test("Copy button script uses clipboard API")
    func usesClipboardAPI() {
        let html = MarkdownRenderer.render("```\ncode\n```", isDark: false)
        #expect(html.contains("navigator.clipboard.writeText"))
    }

    @Test("Copy button shows 'Copied!' feedback")
    func showsCopiedFeedback() {
        let html = MarkdownRenderer.render("```\ncode\n```")
        #expect(html.contains("Copied!"))
    }
}

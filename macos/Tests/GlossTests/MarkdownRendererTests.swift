import Testing
@testable import GlossKit

@Suite("MarkdownRenderer")
struct MarkdownRendererTests {

    @Test("Renders heading")
    func heading() {
        let html = MarkdownRenderer.render("# Hello World", isDark: false)
        #expect(html.contains("<h1>"))
        #expect(html.contains("Hello World"))
    }

    @Test("Renders code block with language class")
    func codeBlock() {
        let source = """
        ```swift
        let x = 42
        ```
        """
        let html = MarkdownRenderer.render(source, isDark: false)
        #expect(html.contains("<pre>"))
        #expect(html.contains("<code"))
        #expect(html.contains("let x = 42"))
    }

    @Test("Renders table")
    func table() {
        let source = """
        | A | B |
        |---|---|
        | 1 | 2 |
        """
        let html = MarkdownRenderer.render(source, isDark: false)
        #expect(html.contains("<table>"))
        #expect(html.contains("<th>"))
        #expect(html.contains("<td>"))
    }

    @Test("Dark mode sets html class")
    func darkMode() {
        let html = MarkdownRenderer.render("test", isDark: true)
        #expect(html.contains("class=\"dark\""))
    }

    @Test("Light mode sets html class")
    func lightMode() {
        let html = MarkdownRenderer.render("test", isDark: false)
        #expect(html.contains("class=\"light\""))
    }

    @Test("Empty input renders without error")
    func emptyInput() {
        let html = MarkdownRenderer.render("", isDark: false)
        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("gloss-content"))
    }

    @Test("Renders blockquote")
    func blockquote() {
        let html = MarkdownRenderer.render("> A quote", isDark: false)
        #expect(html.contains("<blockquote>"))
    }

    @Test("Includes CSS theme")
    func includesCSS() {
        let html = MarkdownRenderer.render("test", isDark: false)
        #expect(html.contains("--accent: #0d9488"))
    }

    @Test("Strips YAML frontmatter")
    func stripsFrontmatter() {
        let source = "---\ntitle: Hello\ndate: 2026-01-01\n---\n# Heading"
        let html = MarkdownRenderer.render(source, isDark: false)
        #expect(html.contains("<h1>"))
        #expect(html.contains("Heading"))
        #expect(!html.contains("title: Hello"))
    }

    @Test("Preserves content without frontmatter")
    func noFrontmatter() {
        let source = "# Just a heading\n\nSome text."
        let html = MarkdownRenderer.render(source, isDark: false)
        #expect(html.contains("<h1>"))
        #expect(html.contains("Just a heading"))
    }

    @Test("Does not strip mid-document hr as frontmatter")
    func midDocumentHr() {
        let source = "# Title\n\n---\n\nMore content"
        let html = MarkdownRenderer.render(source, isDark: false)
        #expect(html.contains("Title"))
        #expect(html.contains("More content"))
    }
}

import Testing
@testable import GlossKit

@Suite("Heading IDs & Extraction")
struct HeadingTests {

    // MARK: - Heading IDs in HTML

    @Test("Adds ID to h1")
    func h1ID() {
        let html = MarkdownRenderer.render("# Hello World", isDark: false)
        #expect(html.contains("<h1 id=\"hello-world\">"))
    }

    @Test("Adds ID to h2 with special characters")
    func h2SpecialChars() {
        let html = MarkdownRenderer.render("## What's New?", isDark: false)
        #expect(html.contains("<h2 id=\"whats-new\">"))
    }

    @Test("Handles duplicate headings with suffix")
    func duplicateHeadings() {
        let source = "# Intro\n\n## Intro\n\n### Intro"
        let html = MarkdownRenderer.render(source, isDark: false)
        #expect(html.contains("id=\"intro\""))
        #expect(html.contains("id=\"intro-1\""))
        #expect(html.contains("id=\"intro-2\""))
    }

    @Test("Includes heading anchor script")
    func anchorScript() {
        let html = MarkdownRenderer.render("# Test", isDark: false)
        #expect(html.contains("heading-anchor"))
    }

    // MARK: - Heading Extraction

    @Test("Extracts headings from markdown")
    func extractHeadings() {
        let source = "# Title\n\n## Section 1\n\n### Subsection\n\n## Section 2"
        let headings = MarkdownRenderer.extractHeadings(source)
        #expect(headings.count == 4)
        #expect(headings[0] == HeadingInfo(level: 1, text: "Title", id: "title"))
        #expect(headings[1] == HeadingInfo(level: 2, text: "Section 1", id: "section-1"))
        #expect(headings[2] == HeadingInfo(level: 3, text: "Subsection", id: "subsection"))
        #expect(headings[3] == HeadingInfo(level: 2, text: "Section 2", id: "section-2"))
    }

    @Test("Empty source returns no headings")
    func emptyHeadings() {
        let headings = MarkdownRenderer.extractHeadings("")
        #expect(headings.isEmpty)
    }

    @Test("Non-heading content returns no headings")
    func noHeadings() {
        let headings = MarkdownRenderer.extractHeadings("Just some text.\n\nMore text.")
        #expect(headings.isEmpty)
    }

    @Test("Strips frontmatter before extracting headings")
    func frontmatterStripped() {
        let source = "---\ntitle: Test\n---\n# Real Heading"
        let headings = MarkdownRenderer.extractHeadings(source)
        #expect(headings.count == 1)
        #expect(headings[0].text == "Real Heading")
    }

    // MARK: - Slug Generation

    @Test("Generates correct slug")
    func slugGeneration() {
        #expect(MarkdownRenderer.generateSlug("Hello World") == "hello-world")
        #expect(MarkdownRenderer.generateSlug("What's New?") == "whats-new")
        #expect(MarkdownRenderer.generateSlug("API Reference (v2)") == "api-reference-v2")
        #expect(MarkdownRenderer.generateSlug("CamelCase") == "camelcase")
    }
}

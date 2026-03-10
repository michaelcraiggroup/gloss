import Testing
@testable import GlossKit

@Suite("Frontmatter Parsing")
struct FrontmatterTests {

    @Test("Extracts simple frontmatter")
    func simpleFrontmatter() {
        let source = "---\ntitle: Hello\nauthor: Jane\n---\n# Content"
        let fm = MarkdownRenderer.extractFrontmatter(source)
        #expect(fm != nil)
        #expect(fm!.fields.count == 2)
        #expect(fm!.fields.contains(where: { $0.key == "title" && $0.value == "Hello" }))
        #expect(fm!.fields.contains(where: { $0.key == "author" && $0.value == "Jane" }))
    }

    @Test("Returns nil for no frontmatter")
    func noFrontmatter() {
        let source = "# Just a heading"
        let fm = MarkdownRenderer.extractFrontmatter(source)
        #expect(fm == nil)
    }

    @Test("Returns nil for unclosed frontmatter")
    func unclosedFrontmatter() {
        let source = "---\ntitle: Hello\nNo closing delimiter"
        let fm = MarkdownRenderer.extractFrontmatter(source)
        #expect(fm == nil)
    }

    @Test("Handles list values")
    func listValues() {
        let source = "---\ntags:\n  - swift\n  - macos\n---\n# Content"
        let fm = MarkdownRenderer.extractFrontmatter(source)
        #expect(fm != nil)
        #expect(fm!.fields.contains(where: { $0.key == "tags" && $0.value.contains("swift") }))
    }

    @Test("Handles date values")
    func dateValues() {
        let source = "---\ndate: 2026-01-15\n---\n# Content"
        let fm = MarkdownRenderer.extractFrontmatter(source)
        #expect(fm != nil)
        #expect(fm!.fields.contains(where: { $0.key == "date" }))
    }

    @Test("Raw frontmatter string preserved")
    func rawPreserved() {
        let source = "---\ntitle: Hello\n---\n# Content"
        let fm = MarkdownRenderer.extractFrontmatter(source)
        #expect(fm != nil)
        #expect(fm!.raw.contains("title: Hello"))
    }

    @Test("Empty frontmatter returns nil")
    func emptyFrontmatter() {
        let source = "---\n---\n# Content"
        let fm = MarkdownRenderer.extractFrontmatter(source)
        #expect(fm == nil)
    }
}

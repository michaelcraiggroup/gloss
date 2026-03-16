import Testing
@testable import GlossKit

@Suite("Tag Extraction")
struct TagExtractionTests {

    @Test("Extracts tags from YAML list")
    func yamlList() {
        let source = "---\ntags:\n  - swift\n  - macos\n---\n# Content"
        let tags = MarkdownRenderer.extractTags(source)
        #expect(tags == ["swift", "macos"])
    }

    @Test("Extracts tags from inline YAML list")
    func inlineList() {
        let source = "---\ntags: [swift, macos]\n---\n# Content"
        let tags = MarkdownRenderer.extractTags(source)
        #expect(tags == ["swift", "macos"])
    }

    @Test("Extracts tags from comma-separated string")
    func commaSeparated() {
        let source = "---\ntags: swift, macos, ui\n---\n# Content"
        let tags = MarkdownRenderer.extractTags(source)
        #expect(tags == ["swift", "macos", "ui"])
    }

    @Test("Returns empty for no frontmatter")
    func noFrontmatter() {
        let tags = MarkdownRenderer.extractTags("# Just a heading")
        #expect(tags.isEmpty)
    }

    @Test("Returns empty for no tags field")
    func noTagsField() {
        let source = "---\ntitle: Hello\n---\n# Content"
        let tags = MarkdownRenderer.extractTags(source)
        #expect(tags.isEmpty)
    }

    @Test("Handles single tag")
    func singleTag() {
        let source = "---\ntags:\n  - swift\n---\n# Content"
        let tags = MarkdownRenderer.extractTags(source)
        #expect(tags == ["swift"])
    }

    @Test("Trims whitespace from tags")
    func trimWhitespace() {
        let source = "---\ntags: swift ,  macos \n---\n# Content"
        let tags = MarkdownRenderer.extractTags(source)
        #expect(tags == ["swift", "macos"])
    }
}

import Testing
@testable import GlossKit

@Suite("Wiki-Link Processing")
struct WikiLinkTests {

    @Test("Converts simple wiki-link to markdown link")
    func simpleWikiLink() {
        let result = MarkdownRenderer.preprocessWikiLinks("See [[My Note]]", resolver: { target in
            target == "My Note" ? "My Note.md" : nil
        })
        #expect(result == "See [My Note](My Note.md)")
    }

    @Test("Converts wiki-link with display text")
    func displayText() {
        let result = MarkdownRenderer.preprocessWikiLinks("See [[target|Click Here]]", resolver: { _ in "target.md" })
        #expect(result == "See [Click Here](target.md)")
    }

    @Test("Unresolved wiki-link becomes hash link")
    func unresolved() {
        let result = MarkdownRenderer.preprocessWikiLinks("See [[Missing]]", resolver: { _ in nil })
        #expect(result == "See [Missing](#)")
    }

    @Test("Multiple wiki-links in same line")
    func multipleLinks() {
        let result = MarkdownRenderer.preprocessWikiLinks("See [[A]] and [[B]]", resolver: { target in "\(target).md" })
        #expect(result.contains("[A](A.md)"))
        #expect(result.contains("[B](B.md)"))
    }

    @Test("No wiki-links returns unchanged")
    func noWikiLinks() {
        let source = "Just regular text with [standard link](url)"
        let result = MarkdownRenderer.preprocessWikiLinks(source, resolver: { _ in nil })
        #expect(result == source)
    }

    @Test("Wiki-link in rendered HTML produces anchor tag")
    func renderedHTML() {
        let html = MarkdownRenderer.render("See [[test]]", isDark: false, resolveWikiLink: { _ in "test.md" })
        #expect(html.contains("<a href=\"test.md\">test</a>"))
    }
}

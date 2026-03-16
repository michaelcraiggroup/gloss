import Testing
@testable import GlossKit

@Suite("Link Extraction")
struct LinkExtractionTests {

    @Test("Extracts simple wiki-link")
    func simpleLink() {
        let links = MarkdownRenderer.extractLinks("See [[My Note]]")
        #expect(links.count == 1)
        #expect(links[0].target == "My Note")
        #expect(links[0].linkType == "related")
        #expect(links[0].displayText == nil)
        #expect(links[0].lineNumber == 1)
    }

    @Test("Extracts typed wiki-link")
    func typedLink() {
        let links = MarkdownRenderer.extractLinks("Based on [[research::supports]]")
        #expect(links.count == 1)
        #expect(links[0].target == "research")
        #expect(links[0].linkType == "supports")
    }

    @Test("Extracts wiki-link with display text")
    func displayTextLink() {
        let links = MarkdownRenderer.extractLinks("See [[target|click here]]")
        #expect(links.count == 1)
        #expect(links[0].target == "target")
        #expect(links[0].displayText == "click here")
    }

    @Test("Extracts typed link with display text")
    func typedDisplayLink() {
        let links = MarkdownRenderer.extractLinks("[[note::extends|more info]]")
        #expect(links.count == 1)
        #expect(links[0].target == "note")
        #expect(links[0].linkType == "extends")
        #expect(links[0].displayText == "more info")
    }

    @Test("Extracts multiple links from multiple lines")
    func multipleLinks() {
        let source = "Line 1 [[A]]\nLine 2\nLine 3 [[B::supports]] and [[C|see this]]"
        let links = MarkdownRenderer.extractLinks(source)
        #expect(links.count == 3)
        #expect(links[0].target == "A")
        #expect(links[0].lineNumber == 1)
        #expect(links[1].target == "B")
        #expect(links[1].linkType == "supports")
        #expect(links[1].lineNumber == 3)
        #expect(links[2].target == "C")
        #expect(links[2].displayText == "see this")
        #expect(links[2].lineNumber == 3)
    }

    @Test("Returns empty for no wiki-links")
    func noLinks() {
        let links = MarkdownRenderer.extractLinks("Just regular text")
        #expect(links.isEmpty)
    }

    @Test("Handles links in frontmatter region")
    func linksInFrontmatter() {
        let source = "---\ntitle: Test\n---\n# Heading\n[[note]]"
        let links = MarkdownRenderer.extractLinks(source)
        #expect(links.count == 1)
        #expect(links[0].target == "note")
        #expect(links[0].lineNumber == 5)
    }

    @Test("All link types are recognized")
    func allTypes() {
        let types = ["related", "supports", "contradicts", "extends", "implements", "depends", "supersedes", "references"]
        for type in types {
            let links = MarkdownRenderer.extractLinks("[[target::\(type)]]")
            #expect(links.count == 1)
            #expect(links[0].linkType == type)
        }
    }
}

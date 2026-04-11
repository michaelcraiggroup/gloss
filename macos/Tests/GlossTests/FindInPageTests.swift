import Testing
@testable import GlossKit

@Suite("Find in Page")
struct FindInPageTests {

    @Test("Rendered HTML contains find bar element")
    func hasFindBar() {
        let html = MarkdownRenderer.render("# Hello")
        #expect(html.contains("gloss-find-bar"))
    }

    @Test("Find bar is hidden by default")
    func findBarHiddenByDefault() {
        let html = MarkdownRenderer.render("test")
        #expect(html.contains("bar.hidden = true"))
    }

    @Test("Contains toggleFindBar function")
    func hasToggleFindBar() {
        let html = MarkdownRenderer.render("test")
        #expect(html.contains("glossToggleFindBar"))
    }

    @Test("Contains performFind function using TreeWalker")
    func hasPerformFindWithTreeWalker() {
        let html = MarkdownRenderer.render("test")
        #expect(html.contains("performFind"))
        #expect(html.contains("createTreeWalker"))
    }

    @Test("Contains clearHighlights function")
    func hasClearHighlights() {
        let html = MarkdownRenderer.render("test")
        #expect(html.contains("clearHighlights"))
    }

    @Test("Contains match highlight CSS classes")
    func hasMatchHighlightCSS() {
        let html = MarkdownRenderer.render("test")
        #expect(html.contains("gloss-find-match"))
        #expect(html.contains("gloss-find-current"))
    }

    @Test("Keyboard nav skips when an editable element is focused")
    func keyboardNavSkipsInputFocus() {
        let html = MarkdownRenderer.render("test")
        // Guard must cover INPUT, TEXTAREA, SELECT, and contenteditable so
        // typing in md+ template fields isn't hijacked by vim-style nav keys.
        #expect(html.contains("tag === 'INPUT'"))
        #expect(html.contains("tag === 'TEXTAREA'"))
        #expect(html.contains("tag === 'SELECT'"))
        #expect(html.contains("isContentEditable"))
    }

    @Test("Find bar responds to Cmd+F keydown")
    func respondsToCmdF() {
        let html = MarkdownRenderer.render("test")
        #expect(html.contains("e.metaKey && e.key === 'f'"))
    }
}

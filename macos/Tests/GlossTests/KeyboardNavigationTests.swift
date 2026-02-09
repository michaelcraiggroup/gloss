import Testing
@testable import GlossKit

@Suite("Keyboard Navigation")
struct KeyboardNavigationTests {

    @Test("Rendered HTML contains keyboard event listener")
    func hasKeyboardListener() {
        let html = MarkdownRenderer.render("# Hello")
        #expect(html.contains("addEventListener('keydown'"))
    }

    @Test("Supports j/k scrolling")
    func supportsJKScrolling() {
        let html = MarkdownRenderer.render("test")
        #expect(html.contains("key === 'j'"))
        #expect(html.contains("key === 'k'"))
    }

    @Test("Supports gg to scroll to top")
    func supportsGGToTop() {
        let html = MarkdownRenderer.render("test")
        #expect(html.contains("pending === 'g'"))
        #expect(html.contains("scrollTo"))
    }

    @Test("Supports G to scroll to bottom")
    func supportsGToBottom() {
        let html = MarkdownRenderer.render("test")
        #expect(html.contains("key === 'G'"))
        #expect(html.contains("document.body.scrollHeight"))
    }

    @Test("Supports Space/Shift+Space page scrolling")
    func supportsSpacePageScroll() {
        let html = MarkdownRenderer.render("test")
        #expect(html.contains("key === ' '"))
        #expect(html.contains("e.shiftKey"))
    }

    @Test("Skips when modifier keys are pressed")
    func skipsModifierKeys() {
        let html = MarkdownRenderer.render("test")
        #expect(html.contains("e.metaKey || e.ctrlKey || e.altKey"))
    }
}

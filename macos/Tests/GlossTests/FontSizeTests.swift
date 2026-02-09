import Testing
@testable import GlossKit

@Suite("Font Size")
struct FontSizeTests {

    @Test("Default font size uses CSS default (no override)")
    func defaultFontSize() {
        let html = MarkdownRenderer.render("Hello", isDark: false)
        // Default 16px should not inject an override style
        #expect(!html.contains("--font-size: 16px; }"))
    }

    @Test("Custom font size injects CSS override")
    func customFontSize() {
        let html = MarkdownRenderer.render("Hello", isDark: false, fontSize: 20)
        #expect(html.contains("--font-size: 20px"))
    }

    @Test("Small font size injects correctly")
    func smallFontSize() {
        let html = MarkdownRenderer.render("Hello", fontSize: 12)
        #expect(html.contains("--font-size: 12px"))
    }

    @Test("Large font size injects correctly")
    func largeFontSize() {
        let html = MarkdownRenderer.render("Hello", fontSize: 24)
        #expect(html.contains("--font-size: 24px"))
    }
}

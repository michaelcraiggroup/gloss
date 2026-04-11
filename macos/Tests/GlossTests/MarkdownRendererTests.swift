import Testing
@testable import GlossKit

@Suite("MarkdownRenderer")
struct MarkdownRendererTests {

    @Test("Renders heading with ID")
    func heading() {
        let html = MarkdownRenderer.render("# Hello World", isDark: false)
        #expect(html.contains("<h1 id=\"hello-world\">"))
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
        // Night Owl light-mode accent — updated from the old Teal #0d9488
        #expect(html.contains("--accent: #4876d6"))
    }

    @Test("Strips YAML frontmatter")
    func stripsFrontmatter() {
        let source = "---\ntitle: Hello\ndate: 2026-01-01\n---\n# Heading"
        let html = MarkdownRenderer.render(source, isDark: false)
        #expect(html.contains("<h1 id=\"heading\">"))
        #expect(html.contains("Heading"))
        #expect(!html.contains("title: Hello"))
    }

    @Test("Preserves content without frontmatter")
    func noFrontmatter() {
        let source = "# Just a heading\n\nSome text."
        let html = MarkdownRenderer.render(source, isDark: false)
        #expect(html.contains("<h1 id=\"just-a-heading\">"))
        #expect(html.contains("Just a heading"))
    }

    @Test("Does not strip mid-document hr as frontmatter")
    func midDocumentHr() {
        let source = "# Title\n\n---\n\nMore content"
        let html = MarkdownRenderer.render(source, isDark: false)
        #expect(html.contains("Title"))
        #expect(html.contains("More content"))
    }

    @Test("Escapes angle brackets in inline code")
    func inlineCodeAngleBrackets() {
        let html = MarkdownRenderer.render("Use `<temperature>` for values", isDark: false)
        #expect(html.contains("&lt;temperature&gt;"))
        #expect(!html.contains("<temperature>"))
    }

    @Test("Escapes angle brackets in code blocks")
    func codeBlockAngleBrackets() {
        let source = """
        ```
        List<String> items = new ArrayList<>();
        ```
        """
        let html = MarkdownRenderer.render(source, isDark: false)
        #expect(html.contains("&lt;String&gt;"))
    }

    @Test("Task list checkboxes are interactive and indexed")
    func taskListCheckboxes() {
        let source = "- [ ] Unchecked\n- [x] Checked"
        let html = MarkdownRenderer.render(source, isDark: false)
        // Both checkboxes are no longer disabled — they're clickable.
        #expect(!html.contains("disabled=\"\""))
        // They're sequentially indexed for the Save Filled Copy flow.
        #expect(html.contains("data-gloss-task-index=\"0\""))
        #expect(html.contains("data-gloss-task-index=\"1\""))
        // Checked state preserved on the second one.
        #expect(html.contains("checked=\"\""))
        // Parent <li> is tagged with the class the CSS targets (so we
        // don't need the expensive `:has()` selector).
        #expect(html.contains("<li class=\"gloss-task-item\">"))
    }

    @Test("hasFillableContent detects task lists")
    func detectsTaskLists() {
        #expect(MarkdownRenderer.hasFillableContent("- [ ] todo"))
        #expect(MarkdownRenderer.hasFillableContent("- [x] done"))
        #expect(!MarkdownRenderer.hasFillableContent("# Just a heading"))
    }

    @Test("Renders md+ template block as a fieldset")
    func templateBlockRenders() {
        let source = """
        # Doc

        <!--md+
        type: template
        id: demo
        name: Demo Form
        fields:
          - name: who
            type: text
            label: Your Name
        -->
        """
        let html = MarkdownRenderer.render(source, isDark: false)
        #expect(html.contains("gloss-mdplus-template"))
        #expect(html.contains("Demo Form"))
        #expect(html.contains("data-gloss-mdplus-block=\"demo\""))
        #expect(html.contains("data-gloss-mdplus-field=\"who\""))
        #expect(html.contains("Your Name"))
        // Template fill script is injected
        #expect(html.contains("window.glossTemplate"))
    }

    @Test("Fillable script absent for plain markdown")
    func fillableScriptAbsent() {
        let html = MarkdownRenderer.render("# Plain\n\nSome text.", isDark: false)
        #expect(!html.contains("window.glossTemplate"))
    }
}

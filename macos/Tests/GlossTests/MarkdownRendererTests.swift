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

    @Test("extractProperties returns scalar frontmatter, excluding tags")
    func extractProperties() {
        let source = """
        ---
        title: My Note
        status: open
        priority: 2
        done: false
        tags: [project, idea]
        items:
          - one
          - two
        ---
        # Body
        """
        let props = MarkdownRenderer.extractProperties(source)
        let dict = Dictionary(uniqueKeysWithValues: props.map { ($0.key, $0.value) })
        #expect(dict["title"] == "My Note")
        #expect(dict["status"] == "open")
        #expect(dict["priority"] == "2")
        #expect(dict["done"] == "false")
        #expect(dict["tags"] == nil)    // excluded — tags has its own table
        #expect(dict["items"] == nil)   // list value skipped in v1
    }

    // MARK: - Transclusion (M2)

    @Test("extractSection pulls a section, includes subsections, stops at next same-level")
    func extractSectionBasic() {
        let source = """
        # Title

        intro

        ## Overview

        overview body

        ### Detail

        detail body

        ## Next

        next body
        """
        let section = MarkdownRenderer.extractSection(source, heading: "Overview")
        #expect(section != nil)
        #expect(section!.contains("## Overview"))
        #expect(section!.contains("overview body"))
        #expect(section!.contains("### Detail"))   // deeper subsection included
        #expect(!section!.contains("## Next"))      // stops at next same-level heading
        #expect(!section!.contains("intro"))        // excludes content before the section
    }

    @Test("extractSection matches by slug, returns nil when missing")
    func extractSectionSlugAndMissing() {
        let source = "# A\n\n## My Section\n\nbody\n"
        #expect(MarkdownRenderer.extractSection(source, heading: "my-section")?.contains("body") == true)
        #expect(MarkdownRenderer.extractSection(source, heading: "Nope") == nil)
    }

    @Test("extractSection ignores headings inside code fences")
    func extractSectionFenceAware() {
        let source = """
        ## Real

        ```
        ## Fake heading in code
        ```

        still real
        """
        let section = MarkdownRenderer.extractSection(source, heading: "Real")
        #expect(section?.contains("Fake heading in code") == true)
        #expect(section?.contains("still real") == true)
    }

    @Test("Transclusion embeds resolved content")
    func transclusionEmbeds() {
        let html = MarkdownRenderer.render(
            "Before\n\n![[note]]\n\nAfter", isDark: false,
            resolveEmbed: { target, _ in target == "note" ? "# Embedded\n\nhello world" : nil })
        #expect(html.contains("gloss-embed"))
        #expect(html.contains("Embedded"))
        #expect(html.contains("hello world"))
        #expect(html.contains("Before"))
        #expect(html.contains("After"))
    }

    @Test("Transclusion runs before wiki-links (no broken image)")
    func transclusionBeforeWikiLinks() {
        let html = MarkdownRenderer.render(
            "![[note]]", isDark: false,
            resolveWikiLink: { _ in "file:///x.md" },
            resolveEmbed: { _, _ in "embedded body" })
        #expect(html.contains("embedded body"))
        #expect(!html.contains("<img"))
    }

    @Test("Transclusion with heading embeds only that section")
    func transclusionSection() {
        let note = "# Doc\n\n## Alpha\n\nalpha text\n\n## Beta\n\nbeta text"
        let html = MarkdownRenderer.render(
            "![[doc#Beta]]", isDark: false,
            resolveEmbed: { target, heading in
                target == "doc" ? MarkdownRenderer.extractSection(note, heading: heading ?? "") : nil
            })
        #expect(html.contains("beta text"))
        #expect(!html.contains("alpha text"))
    }

    @Test("Unresolved embed renders a placeholder")
    func transclusionPlaceholder() {
        let html = MarkdownRenderer.render("![[missing]]", isDark: false)
        #expect(html.contains("gloss-embed-unresolved"))
        #expect(html.contains("open in Gloss"))
    }

    @Test("Embeds do not recurse (one level only)")
    func transclusionNoRecursion() {
        let html = MarkdownRenderer.render(
            "![[outer]]", isDark: false,
            resolveEmbed: { target, _ in
                target == "outer" ? "outer body ![[inner]]" : "INNER BODY"
            })
        #expect(html.contains("outer body"))
        #expect(!html.contains("INNER BODY"))   // nested embed not expanded
    }

    // MARK: - Editable frontmatter (M3)

    @Test("setFrontmatterValue changes a scalar, preserving other keys and body")
    func setFrontmatterExisting() {
        let source = "---\ntitle: Note\nstatus: draft\ntags: [a, b]\n---\n# Body\n\ntext"
        let out = MarkdownRenderer.setFrontmatterValue(source, key: "status", value: "open")
        #expect(out.contains("status: open"))
        #expect(!out.contains("status: draft"))
        #expect(out.contains("title: Note"))     // other keys preserved
        #expect(out.contains("tags: [a, b]"))     // untouched
        #expect(out.contains("# Body") && out.contains("text"))
        #expect(MarkdownRenderer.extractProperties(out).contains { $0.key == "status" && $0.value == "open" })
    }

    @Test("setFrontmatterValue adds a missing key")
    func setFrontmatterAdd() {
        let out = MarkdownRenderer.setFrontmatterValue("---\ntitle: Note\n---\nbody", key: "status", value: "open")
        #expect(out.contains("title: Note") && out.contains("status: open") && out.contains("body"))
    }

    @Test("setFrontmatterValue creates a block when there's no frontmatter")
    func setFrontmatterCreate() {
        let out = MarkdownRenderer.setFrontmatterValue("# Just a heading\n\ntext", key: "status", value: "open")
        #expect(out.hasPrefix("---\nstatus: open\n---\n"))
        #expect(out.contains("# Just a heading"))
    }

    @Test("setFrontmatterValue leaves the body byte-for-byte identical")
    func setFrontmatterBodyPreserved() {
        let body = "# Title\n\nSome *markdown* with `code`.\n"
        let out = MarkdownRenderer.setFrontmatterValue("---\nstatus: draft\n---\n\(body)", key: "status", value: "done")
        #expect(MarkdownRenderer.stripFrontmatter(out) == body)
    }

    @Test("removeFrontmatterKey drops the key, and the block when empty")
    func removeFrontmatterKeyDropsBlock() {
        let afterOne = MarkdownRenderer.removeFrontmatterKey("---\ntitle: Note\nstatus: draft\n---\nbody", key: "status")
        #expect(!afterOne.contains("status") && afterOne.contains("title: Note"))
        let afterAll = MarkdownRenderer.removeFrontmatterKey("---\nstatus: draft\n---\nbody", key: "status")
        #expect(!afterAll.contains("---") && afterAll.contains("body"))
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
        // Brand amber light-mode accent (was Night Owl blue #4876d6)
        #expect(html.contains("--accent: #B45309"))
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

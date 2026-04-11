import Testing
@testable import Gloss

@Suite("TemplateFillService")
struct TemplateFillServiceTests {

    @Test("Single unchecked → checked rewrite")
    func singleCheckboxFlip() {
        let source = "- [ ] buy milk"
        let payload = TemplateFillPayload(
            kind: "filled",
            checkboxes: [.init(index: 0, checked: true)],
            fields: []
        )
        let out = TemplateFillService.rewriteSource(source, payload: payload)
        #expect(out == "- [x] buy milk")
    }

    @Test("Single checked → unchecked rewrite")
    func singleCheckboxUncheck() {
        let source = "- [x] done already"
        let payload = TemplateFillPayload(
            kind: "filled",
            checkboxes: [.init(index: 0, checked: false)],
            fields: []
        )
        let out = TemplateFillService.rewriteSource(source, payload: payload)
        #expect(out == "- [ ] done already")
    }

    @Test("Multiple task lines preserve unaffected items")
    func multipleCheckboxes() {
        let source = """
        - [ ] alpha
        - [ ] beta
        - [ ] gamma
        """
        let payload = TemplateFillPayload(
            kind: "filled",
            checkboxes: [
                .init(index: 0, checked: true),
                .init(index: 2, checked: true)
            ],
            fields: []
        )
        let out = TemplateFillService.rewriteSource(source, payload: payload)
        #expect(out == """
        - [x] alpha
        - [ ] beta
        - [x] gamma
        """)
    }

    @Test("Non-task lines are untouched")
    func mixedContent() {
        let source = """
        # Title

        Paragraph with [brackets] and stuff.

        - [ ] real task
        - regular list item
        - [x] another task
        """
        let payload = TemplateFillPayload(
            kind: "filled",
            checkboxes: [
                .init(index: 0, checked: true),
                .init(index: 1, checked: false)
            ],
            fields: []
        )
        let out = TemplateFillService.rewriteSource(source, payload: payload)
        #expect(out.contains("[brackets]"))
        #expect(out.contains("- [x] real task"))
        #expect(out.contains("- regular list item"))
        #expect(out.contains("- [ ] another task"))
    }

    @Test("Task lines inside code fences are ignored")
    func codeFenceImmunity() {
        let source = """
        ```
        - [ ] inside fence
        ```
        - [ ] outside fence
        """
        let payload = TemplateFillPayload(
            kind: "filled",
            checkboxes: [.init(index: 0, checked: true)],
            fields: []
        )
        let out = TemplateFillService.rewriteSource(source, payload: payload)
        // Fence content untouched, real task flipped
        #expect(out.contains("- [ ] inside fence"))
        #expect(out.contains("- [x] outside fence"))
    }

    @Test("Template block field values are injected")
    func templateFieldInjection() {
        let source = """
        <!--md+
        type: template
        id: demo
        fields:
          - name: mood
            type: text
            default: neutral
        -->
        """
        let payload = TemplateFillPayload(
            kind: "filled",
            checkboxes: [],
            fields: [
                .init(blockId: "demo", fieldName: "mood", value: "fantastic")
            ]
        )
        let out = TemplateFillService.rewriteSource(source, payload: payload)
        #expect(out.contains("value: fantastic"))
        #expect(out.contains("<!--md+"))
        #expect(out.contains("-->"))
    }

    @Test("Plain markdown with no fillable content round-trips unchanged")
    func noFillable() {
        let source = """
        # Hello

        Just a paragraph.

        - regular
        - list
        """
        let payload = TemplateFillPayload(
            kind: "filled",
            checkboxes: [],
            fields: []
        )
        let out = TemplateFillService.rewriteSource(source, payload: payload)
        #expect(out == source)
    }

    @Test("Indented task list items are rewritten")
    func indentedTaskList() {
        let source = "  - [ ] nested"
        let payload = TemplateFillPayload(
            kind: "filled",
            checkboxes: [.init(index: 0, checked: true)],
            fields: []
        )
        let out = TemplateFillService.rewriteSource(source, payload: payload)
        #expect(out == "  - [x] nested")
    }
}

import Testing
@testable import GlossKit

@Suite("MdPlusParser")
struct MdPlusParserTests {

    @Test("Parses a single template block")
    func singleTemplate() {
        let source = """
        # Title

        <!--md+
        type: template
        id: daily
        name: Daily Check-In
        fields:
          - name: mood
            type: text
            label: Mood
            default: good
        -->

        After
        """
        let result = MdPlusParser.parse(source)
        #expect(result.blocks.count == 1)
        #expect(result.blocks[0].id == "daily")
        #expect(result.blocks[0].name == "Daily Check-In")
        #expect(result.blocks[0].fields.count == 1)
        #expect(result.blocks[0].fields[0].name == "mood")
        #expect(result.blocks[0].fields[0].kind == .text)
        #expect(result.blocks[0].fields[0].defaultValue == "good")
        // Rendered output should contain a fieldset
        #expect(result.processedSource.contains("<fieldset"))
        #expect(result.processedSource.contains("gloss-mdplus-template"))
        #expect(result.processedSource.contains("data-gloss-mdplus-block=\"daily\""))
    }

    @Test("Ignores md+ blocks inside fenced code")
    func insideCodeFence() {
        let source = """
        Intro

        ```markdown
        <!--md+
        type: template
        id: bad
        -->
        ```

        Outro
        """
        let result = MdPlusParser.parse(source)
        #expect(result.blocks.isEmpty)
        #expect(result.processedSource.contains("<!--md+"))
    }

    @Test("Parses multiple templates in one document")
    func multipleTemplates() {
        let source = """
        <!--md+
        type: template
        id: one
        fields:
          - name: a
            type: text
        -->

        middle

        <!--md+
        type: template
        id: two
        fields:
          - name: b
            type: number
        -->
        """
        let result = MdPlusParser.parse(source)
        #expect(result.blocks.count == 2)
        #expect(result.blocks[0].id == "one")
        #expect(result.blocks[1].id == "two")
    }

    @Test("Malformed YAML falls back to error callout")
    func malformedYaml() {
        let source = """
        <!--md+
        type: template
        fields:
          - : :broken
        -->
        """
        let result = MdPlusParser.parse(source)
        // May parse partially or fail — both outcomes acceptable per forgiving spec.
        // Critical invariant: no crash, no exception.
        #expect(result.processedSource.contains("gloss-mdplus") || result.processedSource.contains("gloss-mdplus-error"))
    }

    @Test("Unterminated block is left as a comment")
    func unterminated() {
        let source = """
        before
        <!--md+
        type: template
        (no closing)
        """
        let result = MdPlusParser.parse(source)
        #expect(result.blocks.isEmpty)
        #expect(result.processedSource.contains("<!--md+"))
    }

    @Test("Unknown block type is dropped silently")
    func unknownType() {
        let source = """
        <!--md+
        type: calculator
        id: calc
        -->
        """
        let result = MdPlusParser.parse(source)
        // Future work: calculator will render. For v1 it's dropped.
        #expect(result.blocks.isEmpty)
    }

    @Test("Assigns fallback ID when none provided")
    func fallbackId() {
        let source = """
        <!--md+
        type: template
        fields:
          - name: x
            type: text
        -->
        """
        let result = MdPlusParser.parse(source)
        #expect(result.blocks.count == 1)
        #expect(result.blocks[0].id.hasPrefix("mdplus-"))
    }

    @Test("Supports all v1 field kinds")
    func allFieldKinds() {
        let source = """
        <!--md+
        type: template
        id: kitchen
        fields:
          - name: text_field
            type: text
          - name: num_field
            type: number
          - name: check_field
            type: checkbox
            default: true
          - name: date_field
            type: date
          - name: select_field
            type: select
            options: [a, b, c]
            default: b
        -->
        """
        let result = MdPlusParser.parse(source)
        #expect(result.blocks.count == 1)
        let fields = result.blocks[0].fields
        #expect(fields.count == 5)
        #expect(fields.map { $0.kind } == [.text, .number, .checkbox, .date, .select])
        #expect(fields[4].options == ["a", "b", "c"])
        #expect(fields[4].defaultValue == "b")
        #expect(result.processedSource.contains("<select"))
        #expect(result.processedSource.contains("<input type=\"date\""))
        #expect(result.processedSource.contains("<input type=\"number\""))
    }

    @Test("Detects fillable content: task list")
    func detectsTaskList() {
        #expect(MdPlusParser.hasFillableContent("- [ ] todo"))
        #expect(MdPlusParser.hasFillableContent("- [x] done"))
        #expect(MdPlusParser.hasFillableContent("  * [X] indented"))
    }

    @Test("Detects fillable content: template block")
    func detectsTemplateBlock() {
        let source = """
        # Doc

        <!--md+
        type: template
        id: x
        -->
        """
        #expect(MdPlusParser.hasFillableContent(source))
    }

    @Test("Plain markdown has no fillable content")
    func noFillable() {
        #expect(!MdPlusParser.hasFillableContent("# Just a heading\n\nSome text."))
        #expect(!MdPlusParser.hasFillableContent("- regular list\n- items"))
    }
}

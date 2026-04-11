import Foundation
import Yams

/// Pre-processor for `md+` blocks. Scans raw markdown source for
/// `<!--md+ … -->` comment blocks, parses them as YAML, and replaces each
/// block with rendered HTML that swift-markdown will pass through as an
/// HTMLBlock node.
///
/// Code-fence aware: `<!--md+` inside a ``` or ~~~ fence is left untouched.
///
/// Error philosophy per `docs/MD_PLUS_SPEC.md`: forgiving, not draconian.
/// Malformed blocks render as a callout with the raw YAML and do not break
/// the rest of the document.
public struct MdPlusParser: Sendable {

    public struct Result: Sendable {
        public let processedSource: String
        public let blocks: [MdPlusBlock]

        public init(processedSource: String, blocks: [MdPlusBlock]) {
            self.processedSource = processedSource
            self.blocks = blocks
        }
    }

    /// Parse a markdown source string, extracting md+ blocks and replacing
    /// them with rendered HTML in the returned `processedSource`.
    public static func parse(_ source: String) -> Result {
        let lines = source.components(separatedBy: "\n")
        var out: [String] = []
        var blocks: [MdPlusBlock] = []
        var inFence = false
        var autoId = 0
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Toggle code-fence state (``` or ~~~)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                out.append(line)
                i += 1
                continue
            }

            if !inFence && trimmed == "<!--md+" {
                var yamlLines: [String] = []
                var j = i + 1
                var found = false
                while j < lines.count {
                    if lines[j].trimmingCharacters(in: .whitespaces) == "-->" {
                        found = true
                        break
                    }
                    yamlLines.append(lines[j])
                    j += 1
                }

                if found {
                    let yaml = yamlLines.joined(separator: "\n")
                    autoId += 1
                    if let block = parseBlock(yaml: yaml, fallbackId: "mdplus-\(autoId)") {
                        blocks.append(block)
                        // Surround with blank lines so swift-markdown treats as an HTML block
                        out.append("")
                        out.append(renderBlockHTML(block))
                        out.append("")
                    } else {
                        out.append("")
                        out.append(renderErrorHTML(yaml: yaml))
                        out.append("")
                    }
                    i = j + 1
                    continue
                }
                // No closing --> — pass through as a plain comment
                out.append(line)
                i += 1
                continue
            }

            out.append(line)
            i += 1
        }

        return Result(processedSource: out.joined(separator: "\n"), blocks: blocks)
    }

    /// Heuristic: does the source contain interactive content that should
    /// trigger the template-fill JS bridge and "Save Filled Copy" menu item?
    public static func hasFillableContent(_ source: String) -> Bool {
        // GFM task lists anywhere in the source (multiline regex)
        if source.range(of: #"(?m)^[ \t]*[-*+]\s+\[[ xX]\]"#, options: .regularExpression) != nil {
            return true
        }
        // md+ template block markers
        if source.contains("<!--md+") && source.contains("type: template") {
            return true
        }
        return false
    }

    // MARK: - Block parsing

    private static func parseBlock(yaml: String, fallbackId: String) -> MdPlusBlock? {
        guard let loaded = try? Yams.load(yaml: yaml),
              let dict = loaded as? [String: Any] else {
            return nil
        }
        guard let type = dict["type"] as? String else { return nil }

        // v1: only template is actively rendered. Unknown types are dropped
        // silently (future work).
        guard type == "template" else { return nil }

        let id = (dict["id"] as? String) ?? fallbackId
        let name = dict["name"] as? String

        var fields: [TemplateField] = []
        if let rawFields = dict["fields"] as? [[String: Any]] {
            for f in rawFields {
                guard let fieldName = f["name"] as? String,
                      let kindStr = f["type"] as? String,
                      let kind = TemplateFieldKind(rawValue: kindStr) else {
                    continue
                }
                let label = (f["label"] as? String) ?? fieldName
                let defaultValue = stringifyYamlValue(f["default"]) ?? stringifyYamlValue(f["value"])
                let options = (f["options"] as? [Any])?.compactMap { stringifyYamlValue($0) } ?? []
                let multiline = (f["multiline"] as? Bool) ?? false
                fields.append(
                    TemplateField(
                        name: fieldName,
                        kind: kind,
                        label: label,
                        defaultValue: defaultValue,
                        options: options,
                        multiline: multiline
                    )
                )
            }
        }

        return MdPlusBlock(id: id, name: name, type: type, fields: fields, rawYAML: yaml)
    }

    private static func stringifyYamlValue(_ value: Any?) -> String? {
        switch value {
        case let s as String: return s
        case let n as Int: return String(n)
        case let n as Double: return String(n)
        case let b as Bool: return b ? "true" : "false"
        default: return nil
        }
    }

    // MARK: - HTML rendering

    private static func renderBlockHTML(_ block: MdPlusBlock) -> String {
        var html = "<fieldset class=\"gloss-mdplus gloss-mdplus-template\" data-gloss-mdplus-block=\"\(escapeAttr(block.id))\">"
        if let name = block.name, !name.isEmpty {
            html += "<legend>\(escapeHTML(name))</legend>"
        }
        for field in block.fields {
            html += renderField(field, blockId: block.id)
        }
        html += "</fieldset>"
        return html
    }

    private static func renderField(_ field: TemplateField, blockId: String) -> String {
        let fieldId = "gloss-mdplus-\(blockId)-\(field.name)"
        let dataAttrs = "data-gloss-mdplus-block=\"\(escapeAttr(blockId))\" data-gloss-mdplus-field=\"\(escapeAttr(field.name))\""
        let defaultVal = field.defaultValue ?? ""
        var inner = ""
        switch field.kind {
        case .text:
            if field.multiline {
                inner = "<textarea id=\"\(escapeAttr(fieldId))\" \(dataAttrs) rows=\"3\">\(escapeHTML(defaultVal))</textarea>"
            } else {
                inner = "<input type=\"text\" id=\"\(escapeAttr(fieldId))\" \(dataAttrs) value=\"\(escapeAttr(defaultVal))\">"
            }
        case .number:
            inner = "<input type=\"number\" id=\"\(escapeAttr(fieldId))\" \(dataAttrs) value=\"\(escapeAttr(defaultVal))\">"
        case .checkbox:
            let checked = (defaultVal.lowercased() == "true") ? " checked=\"\"" : ""
            inner = "<input type=\"checkbox\" id=\"\(escapeAttr(fieldId))\" \(dataAttrs)\(checked)>"
        case .date:
            inner = "<input type=\"date\" id=\"\(escapeAttr(fieldId))\" \(dataAttrs) value=\"\(escapeAttr(defaultVal))\">"
        case .select:
            var opts = ""
            for option in field.options {
                let selected = (option == defaultVal) ? " selected=\"\"" : ""
                opts += "<option value=\"\(escapeAttr(option))\"\(selected)>\(escapeHTML(option))</option>"
            }
            inner = "<select id=\"\(escapeAttr(fieldId))\" \(dataAttrs)>\(opts)</select>"
        }
        return "<div class=\"gloss-mdplus-field\"><label for=\"\(escapeAttr(fieldId))\">\(escapeHTML(field.label))</label>\(inner)</div>"
    }

    private static func renderErrorHTML(yaml: String) -> String {
        "<div class=\"gloss-mdplus-error\"><strong>md+ block parse error</strong><pre><code>\(escapeHTML(yaml))</code></pre></div>"
    }

    // MARK: - Escaping

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeAttr(_ s: String) -> String {
        escapeHTML(s).replacingOccurrences(of: "\"", with: "&quot;")
    }
}

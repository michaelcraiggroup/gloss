import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Yams

/// Payload posted from the webview's `glossTemplate` message handler to
/// Swift when the user invokes the Save Filled Copy flow.
struct TemplateFillPayload: Codable, Sendable {
    let kind: String
    let checkboxes: [CheckboxState]
    let fields: [FieldValue]

    struct CheckboxState: Codable, Sendable {
        let index: Int
        let checked: Bool
    }

    struct FieldValue: Codable, Sendable {
        let blockId: String
        let fieldName: String
        let value: String
    }
}

/// Coordinates saving a filled-template copy of a markdown document.
///
/// Flow:
/// 1. User invokes File → Save Filled Copy… (or equivalent).
/// 2. GlossApp posts `.glossSaveFilled` notification.
/// 3. WebView coordinator evaluates `window.glossTemplate.collectState()`.
/// 4. JS posts the current DOM state (checkboxes + form fields) back.
/// 5. WebView coordinator posts `.glossTemplateFilled` with the payload.
/// 6. DocumentView receives it and calls `saveFilled(sourceURL:payload:)`.
/// 7. This service rewrites the source and writes to an NSSavePanel URL.
@Observable
@MainActor
final class TemplateFillService {

    init() {}

    /// Rewrite the source file with the given fill state, then prompt the
    /// user for a destination and write the result.
    func saveFilled(sourceURL: URL, payload: TemplateFillPayload) {
        let source: String
        do {
            source = try String(contentsOf: sourceURL, encoding: .utf8)
        } catch {
            showError("Could not read source file: \(error.localizedDescription)")
            return
        }
        let rewritten = Self.rewriteSource(source, payload: payload)

        let panel = NSSavePanel()
        if let markdown = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [markdown, .plainText]
        } else {
            panel.allowedContentTypes = [.plainText]
        }
        let basename = sourceURL.deletingPathExtension().lastPathComponent
        panel.nameFieldStringValue = "\(basename)-filled.md"
        panel.title = "Save Filled Template"
        panel.directoryURL = sourceURL.deletingLastPathComponent()

        guard panel.runModal() == .OK, let destURL = panel.url else { return }

        do {
            try rewritten.write(to: destURL, atomically: true, encoding: .utf8)
            showSavedConfirmation(for: destURL)
        } catch {
            showError("Failed to write file: \(error.localizedDescription)")
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Save Filled Template"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func showSavedConfirmation(for url: URL) {
        let alert = NSAlert()
        alert.messageText = "Filled Copy Saved"
        alert.informativeText = url.lastPathComponent
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Reveal in Finder")
        alert.addButton(withTitle: "OK")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(url)
        case .alertSecondButtonReturn:
            NSWorkspace.shared.activateFileViewerSelecting([url])
        default:
            break
        }
    }

    // MARK: - Pure rewrite (testable, nonisolated)

    /// Rewrite `source` with checkbox and field values from `payload`.
    /// Deterministic, pure, nonisolated — the core of the service's
    /// testability. Code-fence aware.
    nonisolated static func rewriteSource(_ source: String, payload: TemplateFillPayload) -> String {
        let lines = source.components(separatedBy: "\n")
        var out: [String] = []
        var inFence = false
        var taskIndex = 0
        let checkboxMap: [Int: Bool] = Dictionary(
            uniqueKeysWithValues: payload.checkboxes.map { ($0.index, $0.checked) }
        )

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                out.append(line)
                i += 1
                continue
            }

            // md+ template block rewrite
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
                    let rewrittenYaml = rewriteTemplateBlockYaml(yaml: yaml, fields: payload.fields)
                    out.append("<!--md+")
                    for yamlLine in rewrittenYaml.components(separatedBy: "\n") {
                        out.append(yamlLine)
                    }
                    out.append("-->")
                    i = j + 1
                    continue
                }
                // Unterminated — pass through
                out.append(line)
                i += 1
                continue
            }

            // GFM task list rewrite
            if !inFence && isTaskListLine(line) {
                if let checked = checkboxMap[taskIndex] {
                    out.append(rewriteTaskLineMarker(line: line, checked: checked))
                } else {
                    out.append(line)
                }
                taskIndex += 1
                i += 1
                continue
            }

            out.append(line)
            i += 1
        }
        return out.joined(separator: "\n")
    }

    private nonisolated static func isTaskListLine(_ line: String) -> Bool {
        line.range(of: #"^[ \t]*[-*+]\s+\[[ xX]\]"#, options: .regularExpression) != nil
    }

    private nonisolated static func rewriteTaskLineMarker(line: String, checked: Bool) -> String {
        let newMarker = checked ? "[x]" : "[ ]"
        return line.replacingOccurrences(
            of: #"\[[ xX]\]"#,
            with: newMarker,
            options: .regularExpression
        )
    }

    private nonisolated static func rewriteTemplateBlockYaml(
        yaml: String,
        fields: [TemplateFillPayload.FieldValue]
    ) -> String {
        guard let loaded = try? Yams.load(yaml: yaml),
              var dict = loaded as? [String: Any] else {
            return yaml
        }
        guard let blockId = dict["id"] as? String,
              let rawFields = dict["fields"] as? [[String: Any]] else {
            return yaml
        }
        let valueMap: [String: String] = Dictionary(
            uniqueKeysWithValues: fields
                .filter { $0.blockId == blockId }
                .map { ($0.fieldName, $0.value) }
        )
        var newFields: [[String: Any]] = []
        for var field in rawFields {
            if let name = field["name"] as? String, let value = valueMap[name] {
                field["value"] = value
            }
            newFields.append(field)
        }
        dict["fields"] = newFields
        if let dumped = try? Yams.dump(object: dict) {
            return dumped.trimmingCharacters(in: .newlines)
        }
        return yaml
    }
}

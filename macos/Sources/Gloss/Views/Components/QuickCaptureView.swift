import SwiftUI

/// The floating quick-capture card. Type, ⌘↩ to append to today's note, esc to cancel.
struct QuickCaptureView: View {
    let hasVault: Bool
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Color.glossAccent)
                Text("Quick Capture")
                    .font(.headline)
                Spacer()
                Text("→ today's note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .frame(height: 84)
                .focused($focused)

            HStack {
                Text(hasVault ? "⌘↩ to save · esc to cancel" : "Open a folder in Gloss to capture here")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Save", action: submit)
                    .buttonStyle(.borderedProminent)
                    .tint(.glossAccent)
                    .controlSize(.small)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!hasVault || trimmed.isEmpty)
            }
        }
        .padding(14)
        .frame(width: 400, height: 190)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.08)))
        .onExitCommand(perform: onCancel)
        .task { focused = true }
    }

    private func submit() {
        guard hasVault, !trimmed.isEmpty else { return }
        onSubmit(trimmed)
    }
}

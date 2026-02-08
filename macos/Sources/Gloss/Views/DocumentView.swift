import SwiftUI

/// Loads and renders a markdown file, responding to theme changes.
struct DocumentView: View {
    let fileURL: URL?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let url = fileURL {
                if let content = loadFile(at: url) {
                    let html = MarkdownRenderer.render(content, isDark: colorScheme == .dark)
                    WebView(htmlContent: html)
                } else {
                    errorState(message: "Could not read file:\n\(url.lastPathComponent)")
                }
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Open a markdown file to start reading")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("File → Open or drag a .md file here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadFile(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }
}

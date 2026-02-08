import SwiftUI

/// Loads and renders a markdown file, responding to theme changes and file modifications.
struct DocumentView: View {
    let fileURL: URL?
    @Environment(\.colorScheme) private var colorScheme
    @State private var fileContent: String?
    @State private var fileWatcher = FileWatcher()

    var body: some View {
        Group {
            if let url = fileURL {
                if let content = fileContent {
                    let html = MarkdownRenderer.render(content, isDark: colorScheme == .dark)
                    WebView(htmlContent: html)
                } else {
                    errorState(message: "Could not read file:\n\(url.lastPathComponent)")
                }
            } else {
                emptyState
            }
        }
        .onChange(of: fileURL) {
            loadAndWatch()
        }
        .onAppear {
            loadAndWatch()
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

    private func loadAndWatch() {
        guard let url = fileURL else {
            fileContent = nil
            fileWatcher.stop()
            return
        }
        fileContent = try? String(contentsOf: url, encoding: .utf8)
        fileWatcher.watch(url: url) {
            Task { @MainActor [url] in
                fileContent = try? String(contentsOf: url, encoding: .utf8)
            }
        }
    }
}

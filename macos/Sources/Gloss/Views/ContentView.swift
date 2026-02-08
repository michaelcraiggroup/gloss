import SwiftUI
import UniformTypeIdentifiers

/// Main window layout with sidebar file browser and document detail pane.
struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(FileTreeModel.self) private var fileTree
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } detail: {
            DocumentView(fileURL: settings.currentFileURL)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            openInEditor()
                        } label: {
                            Label("Open in Editor", systemImage: "pencil.and.outline")
                        }
                        .help("Open in \(settings.editor.displayName) (⇧⌘E)")
                        .disabled(settings.currentFileURL == nil)
                    }
                }
                .navigationTitle(settings.currentFileURL?.lastPathComponent ?? "Gloss")
                .navigationSubtitle(settings.currentFileURL != nil ? "Reading Mode" : "")
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private func openInEditor() {
        guard let url = settings.currentFileURL else { return }
        EditorLauncher.open(fileAt: url.path, with: settings.editor)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
            if let data = data as? Data,
               let path = String(data: data, encoding: .utf8),
               let url = URL(string: path),
               url.pathExtension.lowercased() == "md" || url.pathExtension.lowercased() == "markdown" {
                DispatchQueue.main.async {
                    settings.currentFileURL = url
                    settings.lastOpenedFile = url.path
                }
            }
        }
        return true
    }
}

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Main window layout with sidebar file browser and document detail pane.
struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(FileTreeModel.self) private var fileTree
    @Environment(\.modelContext) private var modelContext
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } detail: {
            DocumentView(fileURL: settings.currentFileURL)
                .toolbar {
                    if settings.currentFileURL != nil {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                toggleFavoriteForCurrentFile()
                            } label: {
                                Label(
                                    "Toggle Favorite",
                                    systemImage: isCurrentFileFavorited ? "star.fill" : "star"
                                )
                            }
                            .foregroundStyle(isCurrentFileFavorited ? .yellow : .secondary)
                            .help("Toggle Favorite (⌘D)")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            openInEditor()
                        } label: {
                            Label("Open in Editor", systemImage: "pencil.and.outline")
                        }
                        .help("Open in \(settings.editor.displayName) (⇧⌘E)")
                        .disabled(settings.currentFileURL == nil)
                    }
                    if settings.currentFileURL != nil {
                        ToolbarItem(placement: .status) {
                            Text("j/k to scroll")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .navigationTitle(settings.currentFileURL?.lastPathComponent ?? "Gloss")
                .navigationSubtitle(settings.currentFileURL != nil ? "Reading Mode" : "")
        }
        .focusedSceneValue(\.toggleFavorite, toggleFavoriteForCurrentFile)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Favorites

    private var isCurrentFileFavorited: Bool {
        guard let url = settings.currentFileURL else { return false }
        let path = url.path
        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.path == path && $0.isFavorite }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }

    private func toggleFavoriteForCurrentFile() {
        guard let url = settings.currentFileURL else { return }
        let path = url.path
        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.path == path }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.isFavorite.toggle()
        } else {
            let filename = url.lastPathComponent
            let parentFolder = url.deletingLastPathComponent().lastPathComponent
            let docType = DocumentType.detect(filename: filename, folderName: parentFolder)
            let title = filename.replacingOccurrences(of: ".md", with: "")
                .replacingOccurrences(of: ".markdown", with: "")
            let doc = RecentDocument(path: path, title: title, documentType: docType.rawValue, isFavorite: true)
            modelContext.insert(doc)
        }
    }

    // MARK: - Editor

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

// MARK: - FocusedValues

struct FavoriteToggleKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var toggleFavorite: (() -> Void)? {
        get { self[FavoriteToggleKey.self] }
        set { self[FavoriteToggleKey.self] = newValue }
    }
}

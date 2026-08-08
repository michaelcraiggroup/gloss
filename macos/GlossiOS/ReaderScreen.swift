import SwiftUI
import GlossKit

/// The iOS reader: owns a DocumentRenderModel instance (the same pipeline the
/// macOS DocumentView calls statically) and mirrors its trigger surface —
/// re-render on theme/font changes, live reload when the vault observer
/// reports the open file changed, and unresolved-wiki-link re-probes when the
/// index catches up.
struct ReaderScreen: View {
    let fileURL: URL
    let navHistory: NavigationHistory

    @EnvironmentObject private var settings: AppSettings
    @Environment(LinkIndex.self) private var linkIndex
    @Environment(\.colorScheme) private var colorScheme
    @State private var model = DocumentRenderModel()
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            if let html = model.renderedHTML, model.renderURL == fileURL {
                ReaderWebView(
                    htmlContent: html,
                    baseURL: fileURL.deletingLastPathComponent()
                )
                .ignoresSafeArea(edges: .bottom)
            } else if loadFailed {
                ContentUnavailableView(
                    "Could not read file",
                    systemImage: "exclamationmark.triangle",
                    description: Text(fileURL.lastPathComponent)
                )
            } else {
                ProgressView()
            }
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    if let url = navHistory.goBack(from: settings.currentFileURL) {
                        settings.currentFileURL = url
                    }
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(!navHistory.canGoBack)
                .accessibilityLabel("Back")

                Button {
                    if let url = navHistory.goForward(from: settings.currentFileURL) {
                        settings.currentFileURL = url
                    }
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(!navHistory.canGoForward)
                .accessibilityLabel("Forward")
            }
        }
        .onAppear {
            model.database = { linkIndex.databaseRef }
            loadAndRender()
        }
        .onChange(of: fileURL) {
            loadAndRender()
        }
        .onChange(of: colorScheme) {
            renderCurrent()
        }
        .onChange(of: settings.fontSize) {
            renderCurrent()
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossVaultFilesChanged)) { note in
            // Live-reload the open document when the vault observer reports it
            // changed on disk (arrives via NullVaultObserver's replacement in
            // the sync arc; wired now so PR 9 needs no reader changes).
            guard let paths = note.object as? [String] else { return }
            let target = fileURL.resolvingSymlinksInPath().path
            if paths.contains(target) {
                loadAndRender()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossIndexUpdated)) { _ in
            // A wiki-link that failed to resolve may resolve now — probe just
            // the failed targets and re-render only when one lights up (same
            // guard as macOS DocumentView).
            guard !model.unresolvedWikiTargets.isEmpty,
                  let content = model.fileContent else { return }
            let resolvable = model.unresolvedWikiTargets.contains {
                DocumentRenderModel.resolveWikiLink(
                    $0, from: fileURL, database: linkIndex.databaseRef) != nil
            }
            if resolvable {
                model.render(content, url: fileURL,
                             isDark: colorScheme == .dark, fontSize: settings.fontSize)
            }
        }
        .onDisappear {
            model.cancel()
        }
    }

    private var displayTitle: String {
        let name = fileURL.lastPathComponent
        if name.hasSuffix(".md") { return String(name.dropLast(3)) }
        if name.hasSuffix(".markdown") { return String(name.dropLast(9)) }
        return name
    }

    private func loadAndRender() {
        loadFailed = !model.load(url: fileURL)
        renderCurrent()
    }

    private func renderCurrent() {
        guard let content = model.fileContent else { return }
        model.render(content, url: fileURL,
                     isDark: colorScheme == .dark, fontSize: settings.fontSize)
    }
}

import SwiftUI
import WebKit

/// Detail pane alternative to `DocumentView` — shows the whole vault as a
/// D3 force-directed graph. Rendered inside a WKWebView and driven by
/// `GraphService`. Filters live in a SwiftUI overlay so we can tweak them
/// without reloading the webview.
struct GraphView: View {
    @Environment(GraphService.self) private var graphService
    @Environment(LinkIndex.self) private var linkIndex
    @Environment(FileTreeModel.self) private var fileTree
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settings: AppSettings

    @State private var webView: WKWebView?
    @State private var isWebReady = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GraphWebView(
                data: graphService.data,
                isDark: colorScheme == .dark,
                webView: $webView,
                isReady: $isWebReady,
                onNodeClick: { path in
                    let url = URL(fileURLWithPath: path)
                    settings.currentFileURL = url
                    settings.lastOpenedFile = url.standardizedFileURL.path
                }
            )

            filterPanel
                .padding(16)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            if graphService.data.nodes.isEmpty {
                graphService.refresh(database: linkIndex.databaseRef)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossIndexUpdated)) { _ in
            graphService.refresh(database: linkIndex.databaseRef)
        }
        .navigationTitle("Vault Graph")
        .navigationSubtitle(subtitle)
    }

    private var subtitle: String {
        if graphService.isBuilding { return "Building…" }
        let n = graphService.data.nodes.count
        let e = graphService.data.edges.count
        return "\(n) nodes · \(e) edges"
    }

    // MARK: - Filter Panel

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Filters")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                if graphService.filter != .unfiltered {
                    Button("Reset") {
                        graphService.applyFilter(.unfiltered, database: linkIndex.databaseRef)
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                }
            }

            tagPicker
            linkTypePicker
            depthStepper
            fitButton
        }
        .padding(12)
        .frame(width: 240, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    private var tagPicker: some View {
        HStack(spacing: 6) {
            Image(systemName: "tag")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Menu {
                Button("All tags") {
                    var f = graphService.filter
                    f.tag = nil
                    graphService.applyFilter(f, database: linkIndex.databaseRef)
                }
                if !linkIndex.allTags.isEmpty {
                    Divider()
                    ForEach(linkIndex.allTags.prefix(40), id: \.tag) { item in
                        Button("#\(item.tag) (\(item.count))") {
                            var f = graphService.filter
                            f.tag = item.tag
                            graphService.applyFilter(f, database: linkIndex.databaseRef)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(graphService.filter.tag.map { "#\($0)" } ?? "All tags")
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
            }
            .menuStyle(.borderlessButton)
        }
    }

    private var linkTypePicker: some View {
        HStack(spacing: 6) {
            Image(systemName: "link")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Menu {
                Button("All link types") {
                    var f = graphService.filter
                    f.linkType = nil
                    graphService.applyFilter(f, database: linkIndex.databaseRef)
                }
                Divider()
                ForEach(LinkType.allCases, id: \.self) { type in
                    Button(type.displayName) {
                        var f = graphService.filter
                        f.linkType = type
                        graphService.applyFilter(f, database: linkIndex.databaseRef)
                    }
                }
            } label: {
                HStack {
                    Text(graphService.filter.linkType?.displayName ?? "All link types")
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
            }
            .menuStyle(.borderlessButton)
        }
    }

    @ViewBuilder
    private var depthStepper: some View {
        HStack(spacing: 6) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            if graphService.filter.centerPath != nil {
                Stepper(
                    value: Binding(
                        get: { graphService.filter.maxDepth ?? 2 },
                        set: { newValue in
                            var f = graphService.filter
                            f.maxDepth = newValue
                            graphService.applyFilter(f, database: linkIndex.databaseRef)
                        }
                    ),
                    in: 1...5
                ) {
                    Text("Depth: \(graphService.filter.maxDepth ?? 2)")
                        .font(.caption)
                }
                .controlSize(.small)
            } else {
                Text("Open a doc to center")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var fitButton: some View {
        HStack {
            Button {
                webView?.evaluateJavaScript("fitToWindow()", completionHandler: nil)
            } label: {
                Label("Fit to window", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            Spacer()
            if graphService.isBuilding {
                ProgressView().controlSize(.small)
            }
        }
    }
}

// MARK: - GraphWebView

/// NSViewRepresentable that loads the D3 graph HTML and pushes data into it
/// via `evaluateJavaScript`. Communicates back via a `glossGraph`
/// `WKScriptMessageHandler` for node clicks + ready signals.
struct GraphWebView: NSViewRepresentable {
    let data: GraphData
    let isDark: Bool
    @Binding var webView: WKWebView?
    @Binding var isReady: Bool
    let onNodeClick: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onReady: { isReady = true },
            onNodeClick: onNodeClick
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.userContentController.add(context.coordinator, name: "glossGraph")

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.setValue(false, forKey: "drawsBackground")
        wv.navigationDelegate = context.coordinator
        context.coordinator.webView = wv

        // Load graph.html from the bundle.
        #if XCODE_BUILD
        if let url = Bundle.main.url(forResource: "graph", withExtension: "html") {
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        #else
        if let url = Bundle.module.url(forResource: "graph", withExtension: "html") {
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        #endif

        DispatchQueue.main.async {
            webView = wv
        }
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.pendingData = data
        context.coordinator.pendingIsDark = isDark
        if isReady {
            context.coordinator.flush()
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, @unchecked Sendable {
        let onReady: () -> Void
        let onNodeClick: (String) -> Void
        weak var webView: WKWebView?

        var pendingData: GraphData?
        var pendingIsDark: Bool?
        private var webIsReady = false
        private var lastPushedNodeCount: Int?
        private var lastPushedEdgeCount: Int?
        private var lastPushedIsDark: Bool?

        init(onReady: @escaping () -> Void, onNodeClick: @escaping (String) -> Void) {
            self.onReady = onReady
            self.onNodeClick = onNodeClick
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            // Extract Sendable values BEFORE hopping actors — the raw message
            // holds main-actor-isolated properties.
            MainActor.assumeIsolated {
                guard message.name == "glossGraph" else { return }
                let body: [String: Any]?
                if let dict = message.body as? [String: Any] {
                    body = dict
                } else if let str = message.body as? String,
                          let data = str.data(using: .utf8) {
                    body = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                } else {
                    body = nil
                }
                guard let body, let type = body["type"] as? String else { return }

                switch type {
                case "ready":
                    self.webIsReady = true
                    self.onReady()
                    self.flush()
                case "nodeClick":
                    if let path = body["path"] as? String {
                        self.onNodeClick(path)
                    }
                default:
                    break
                }
            }
        }

        /// Push any pending graph data / theme to the web view if it's ready.
        @MainActor
        func flush() {
            guard webIsReady, let wv = webView else { return }

            if let dark = pendingIsDark, dark != lastPushedIsDark {
                wv.evaluateJavaScript("setTheme(\(dark))", completionHandler: nil)
                lastPushedIsDark = dark
            }

            if let data = pendingData {
                if data.nodes.count != lastPushedNodeCount || data.edges.count != lastPushedEdgeCount {
                    guard let encoded = try? JSONEncoder().encode(data),
                          let json = String(data: encoded, encoding: .utf8) else { return }
                    // JSONEncoder output is already a valid JS literal.
                    wv.evaluateJavaScript("renderGraph(\(json))", completionHandler: nil)
                    lastPushedNodeCount = data.nodes.count
                    lastPushedEdgeCount = data.edges.count
                }
            }
        }
    }
}

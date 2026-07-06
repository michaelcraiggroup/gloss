import SwiftUI

/// User preferences stored via @AppStorage, shared across the app.
@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("preferredEditor") var preferredEditor: String = Editor.cursor.rawValue
    @AppStorage("lastOpenedFile") var lastOpenedFile: String = ""
    @AppStorage("appearance") var appearance: String = Appearance.system.rawValue
    @AppStorage("rootFolderPath") var rootFolderPath: String = ""
    @AppStorage("fontSize") var fontSize: Int = 16
    @AppStorage("customEditorPath") var customEditorPath: String = ""
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("lastSeenVersion") var lastSeenVersion: String = ""
    @AppStorage("dailyNotesFolder") var dailyNotesFolder: String = ""
    @AppStorage("dailyNotesDateFormat") var dailyNotesDateFormat: String = "yyyy-MM-dd"
    @AppStorage("quickCaptureEnabled") var quickCaptureEnabled: Bool = true
    @AppStorage("quickCaptureCorner") var quickCaptureCorner: String = ScreenCorner.bottomLeft.rawValue
    @AppStorage("zoomLevel") var zoomLevel: Double = 1.0

    @Published var currentFileURL: URL?
    @Published var isZenMode: Bool = false

    var screenCorner: ScreenCorner {
        get { ScreenCorner(rawValue: quickCaptureCorner) ?? .bottomLeft }
        set { quickCaptureCorner = newValue.rawValue }
    }

    /// URL of the daily note for `date`, from the configured folder + date format.
    /// Returns nil when no vault is open or the format yields an empty name.
    func dailyNoteURL(for date: Date = Date()) -> URL? {
        guard !rootFolderPath.isEmpty else { return nil }
        let root = URL(fileURLWithPath: rootFolderPath)
        let subfolder = dailyNotesFolder.trimmingCharacters(in: .whitespaces)
        let dir = subfolder.isEmpty ? root : root.appendingPathComponent(subfolder)
        let formatter = DateFormatter()
        let fmt = dailyNotesDateFormat.trimmingCharacters(in: .whitespaces)
        formatter.dateFormat = fmt.isEmpty ? "yyyy-MM-dd" : fmt
        let dateString = formatter.string(from: date)
        guard !dateString.isEmpty else { return nil }
        return dir.appendingPathComponent("\(dateString).md")
    }

    /// Minimal frontmatter template for a freshly-created daily note.
    static func dailyNoteTemplate(title: String) -> String {
        "---\ntitle: \(title)\ntags: [daily]\n---\n\n"
    }

    /// Canonical key for the currently open vault: the standardized root path,
    /// or `""` when no vault is open. This is the ONLY form that may be written
    /// into `RecentDocument.vaultPath` — raw `rootFolderPath` can differ from it
    /// on symlinked or non-normalized paths.
    var vaultKey: String {
        rootFolderPath.isEmpty ? "" : URL(fileURLWithPath: rootFolderPath).standardizedFileURL.path
    }

    // MARK: - Recent vaults (File → Open Recent Vault)

    @AppStorage("recentVaultPaths") private var recentVaultPathsJSON: String = "[]"

    /// Most-recent-first standardized vault paths, capped at 5.
    var recentVaultPaths: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(recentVaultPathsJSON.utf8))) ?? []
    }

    func recordRecentVault(_ path: String) {
        setRecentVaults(Self.updatedRecentVaults(recentVaultPaths, adding: path))
    }

    func removeRecentVault(_ path: String) {
        setRecentVaults(recentVaultPaths.filter { $0 != path })
    }

    func clearRecentVaults() {
        setRecentVaults([])
    }

    /// Pure MRU update — standardizes, dedupes, inserts at the front, caps.
    /// Static so it can be unit-tested without touching UserDefaults.
    nonisolated static func updatedRecentVaults(_ existing: [String], adding path: String, cap: Int = 5) -> [String] {
        guard !path.isEmpty else { return existing }
        let canonical = URL(fileURLWithPath: path).standardizedFileURL.path
        var paths = existing.filter { $0 != canonical }
        paths.insert(canonical, at: 0)
        return Array(paths.prefix(cap))
    }

    private func setRecentVaults(_ paths: [String]) {
        if let data = try? JSONEncoder().encode(paths) {
            recentVaultPathsJSON = String(decoding: data, as: UTF8.self)
        }
    }

    var editor: Editor {
        get { Editor(rawValue: preferredEditor) ?? .cursor }
        set { preferredEditor = newValue.rawValue }
    }

    var colorSchemeAppearance: Appearance {
        get { Appearance(rawValue: appearance) ?? .system }
        set { appearance = newValue.rawValue }
    }

    // MARK: - Document zoom (read-mode page zoom, ⌘+/⌘−/⌘0)

    nonisolated static let zoomRange: ClosedRange<Double> = 0.5...3.0
    nonisolated static let zoomStep: Double = 0.1

    /// Pure, testable zoom transform: applies `delta`, rounds to 2 decimal
    /// places to avoid Double accumulation drift, then clamps to `zoomRange`.
    nonisolated static func steppedZoom(_ current: Double, by delta: Double) -> Double {
        let next = ((current + delta) * 100).rounded() / 100
        return min(max(next, zoomRange.lowerBound), zoomRange.upperBound)
    }

    func zoomIn()    { zoomLevel = Self.steppedZoom(zoomLevel, by:  Self.zoomStep) }
    func zoomOut()   { zoomLevel = Self.steppedZoom(zoomLevel, by: -Self.zoomStep) }
    func resetZoom() { zoomLevel = 1.0 }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// A screen corner used as the quick-capture hot-corner trigger.
enum ScreenCorner: String, CaseIterable, Identifiable {
    case bottomLeft, bottomRight, topLeft, topRight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        }
    }

    /// The corner point in the coordinate space of `frame` (AppKit: bottom-left origin).
    func point(in frame: CGRect) -> CGPoint {
        switch self {
        case .bottomLeft: CGPoint(x: frame.minX, y: frame.minY)
        case .bottomRight: CGPoint(x: frame.maxX, y: frame.minY)
        case .topLeft: CGPoint(x: frame.minX, y: frame.maxY)
        case .topRight: CGPoint(x: frame.maxX, y: frame.maxY)
        }
    }
}

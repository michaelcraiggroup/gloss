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

    var editor: Editor {
        get { Editor(rawValue: preferredEditor) ?? .cursor }
        set { preferredEditor = newValue.rawValue }
    }

    var colorSchemeAppearance: Appearance {
        get { Appearance(rawValue: appearance) ?? .system }
        set { appearance = newValue.rawValue }
    }
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

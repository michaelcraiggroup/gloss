import SwiftUI

/// User preferences stored via @AppStorage, shared across the app.
@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("preferredEditor") var preferredEditor: String = Editor.cursor.rawValue
    @AppStorage("lastOpenedFile") var lastOpenedFile: String = ""
    @AppStorage("appearance") var appearance: String = Appearance.system.rawValue
    @AppStorage("rootFolderPath") var rootFolderPath: String = ""
    @AppStorage("fontSize") var fontSize: Int = 16

    @Published var currentFileURL: URL?

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

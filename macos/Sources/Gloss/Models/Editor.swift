import AppKit

/// Supported external editors for "Open in Editor" functionality.
/// All VS Code forks use URL schemes; system default uses NSWorkspace.
/// "custom" uses a user-selected app bundle.
enum Editor: String, CaseIterable, Codable, Identifiable {
    case cursor = "cursor"
    case windsurf = "windsurf"
    case vscode = "vscode"
    case vscodium = "vscodium"
    case zed = "zed"
    case sublime = "sublime"
    case system = "system"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cursor: "Cursor"
        case .windsurf: "Windsurf"
        case .vscode: "VS Code"
        case .vscodium: "VSCodium"
        case .zed: "Zed"
        case .sublime: "Sublime Text"
        case .system: "System Default"
        case .custom: "Custom App…"
        }
    }

    /// URL scheme prefix for VS Code forks, nil for system default / custom.
    var urlScheme: String? {
        switch self {
        case .cursor: "cursor://file"
        case .windsurf: "windsurf://file"
        case .vscode: "vscode://file"
        case .vscodium: "vscodium://file"
        case .zed: "zed://file"
        case .sublime: "subl://open?url=file://"
        case .system: nil
        case .custom: nil
        }
    }

    func openFile(at path: String) {
        if let scheme = urlScheme, let url = URL(string: "\(scheme)\(path)") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }

    /// Open file using a custom app bundle path.
    static func openFileWithCustomApp(at filePath: String, appPath: String) {
        let appURL = URL(fileURLWithPath: appPath)
        let fileURL = URL(fileURLWithPath: filePath)
        NSWorkspace.shared.open(
            [fileURL],
            withApplicationAt: appURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}

import AppKit

/// Supported external editors for "Open in Editor" functionality.
/// All VS Code forks use URL schemes; system default uses NSWorkspace.
enum Editor: String, CaseIterable, Codable, Identifiable {
    case cursor = "cursor"
    case windsurf = "windsurf"
    case vscode = "vscode"
    case vscodium = "vscodium"
    case system = "system"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cursor: "Cursor"
        case .windsurf: "Windsurf"
        case .vscode: "VS Code"
        case .vscodium: "VSCodium"
        case .system: "System Default"
        }
    }

    /// URL scheme prefix for VS Code forks, nil for system default.
    var urlScheme: String? {
        switch self {
        case .cursor: "cursor://file"
        case .windsurf: "windsurf://file"
        case .vscode: "vscode://file"
        case .vscodium: "vscodium://file"
        case .system: nil
        }
    }

    func openFile(at path: String) {
        if let scheme = urlScheme, let url = URL(string: "\(scheme)\(path)") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }
}

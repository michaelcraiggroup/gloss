import AppKit

/// Opens files in external editors based on user preference.
struct EditorLauncher {
    static func open(fileAt path: String, with editor: Editor) {
        editor.openFile(at: path)
    }
}

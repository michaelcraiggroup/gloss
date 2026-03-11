import AppKit

/// Opens files in external editors based on user preference.
struct EditorLauncher {
    static func open(fileAt path: String, with editor: Editor, customAppPath: String = "") {
        if editor == .custom, !customAppPath.isEmpty {
            Editor.openFileWithCustomApp(at: path, appPath: customAppPath)
        } else {
            editor.openFile(at: path)
        }
    }
}

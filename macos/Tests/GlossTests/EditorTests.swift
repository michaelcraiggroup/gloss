import Foundation
import Testing
@testable import Gloss

@Suite("Editor")
struct EditorTests {

    @Test("All editors have display names")
    func displayNames() {
        for editor in Editor.allCases {
            #expect(!editor.displayName.isEmpty)
        }
    }

    @Test("URL schemes for VS Code forks")
    func urlSchemes() {
        #expect(Editor.cursor.urlScheme == "cursor://file")
        #expect(Editor.windsurf.urlScheme == "windsurf://file")
        #expect(Editor.vscode.urlScheme == "vscode://file")
        #expect(Editor.vscodium.urlScheme == "vscodium://file")
    }

    @Test("System editor has no URL scheme")
    func systemNoScheme() {
        #expect(Editor.system.urlScheme == nil)
    }

    @Test("Codable round-trip")
    func codable() throws {
        let original = Editor.cursor
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Editor.self, from: data)
        #expect(decoded == original)
    }

    @Test("All case identifiers are unique")
    func uniqueIds() {
        let ids = Editor.allCases.map(\.id)
        #expect(Set(ids).count == Editor.allCases.count)
    }
}

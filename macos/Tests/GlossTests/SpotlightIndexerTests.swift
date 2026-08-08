import Foundation
import Testing
@testable import Gloss

@Suite("SpotlightIndexer")
struct SpotlightIndexerTests {
    // MARK: - Snippet

    @Test func snippetSkipsFrontmatterHeadingsAndFurniture() {
        let content = """
        ---
        title: Test
        tags: [x]
        ---

        # Big Heading

        > - The *actual* first prose line.

        More text.
        """
        #expect(SpotlightIndexer.snippet(from: content)
            == "The *actual* first prose line.")
    }

    @Test func snippetCapsLength() {
        let long = String(repeating: "word ", count: 100)
        #expect(SpotlightIndexer.snippet(from: long).count <= 160)
    }

    @Test func snippetOfHeadingsOnlyIsEmpty() {
        #expect(SpotlightIndexer.snippet(from: "# One\n## Two\n") == "")
    }

    // MARK: - Domain + vault-root parsing

    @Test func domainIsResolvedRootPath() {
        let root = URL(fileURLWithPath: "/Users/x/Notes")
        #expect(SpotlightIndexer.domain(forVaultRoot: root) == "/Users/x/Notes")
    }

    @Test func vaultRootParsesContainerPathsOnBothPlatforms() {
        let mac = "/Users/x/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/Documents/Field Notes/sub/note.md"
        #expect(SpotlightIndexer.vaultRoot(forNotePath: mac)?.path
            == "/Users/x/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/Documents/Field Notes")

        let ios = "/private/var/mobile/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/Documents/V/n.md"
        #expect(SpotlightIndexer.vaultRoot(forNotePath: ios)?.path
            == "/private/var/mobile/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/Documents/V")
    }

    @Test func vaultRootIsNilOutsideTheContainer() {
        #expect(SpotlightIndexer.vaultRoot(forNotePath: "/Users/x/Notes/a.md") == nil)
        #expect(SpotlightIndexer.vaultRoot(
            forNotePath: "/x/Mobile Documents/iCloud~com~apple~Pages/Documents/d.md") == nil)
    }
}

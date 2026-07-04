import Testing
import Foundation
@testable import Gloss

@Suite("Recent Vaults")
struct RecentVaultsTests {

    @Test("Insert at front")
    func recordInsertsAtFront() {
        let updated = AppSettings.updatedRecentVaults(["/b", "/c"], adding: "/a")
        #expect(updated == ["/a", "/b", "/c"])
    }

    @Test("Dedupes by standardized path")
    func recordDedupesByStandardizedPath() {
        let updated = AppSettings.updatedRecentVaults(["/vaults/notes", "/b"], adding: "/vaults/x/../notes")
        #expect(updated == ["/vaults/notes", "/b"])
    }

    @Test("Caps at five")
    func capsAtFive() {
        let five = ["/1", "/2", "/3", "/4", "/5"]
        let updated = AppSettings.updatedRecentVaults(five, adding: "/0")
        #expect(updated.count == 5)
        #expect(updated == ["/0", "/1", "/2", "/3", "/4"])
    }

    @Test("Ignores empty path")
    func ignoresEmptyPath() {
        #expect(AppSettings.updatedRecentVaults(["/a"], adding: "") == ["/a"])
    }

    @Test("Paths JSON round-trips")
    func jsonRoundTrips() throws {
        let paths = ["/vault one/with spaces", "/vault-two"]
        let data = try JSONEncoder().encode(paths)
        let decoded = try JSONDecoder().decode([String].self, from: data)
        #expect(decoded == paths)
    }
}

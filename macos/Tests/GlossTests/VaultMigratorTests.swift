import Foundation
import SwiftData
import Testing
@testable import Gloss

@Suite("VaultMigrator")
struct VaultMigratorTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-migrate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Validation

    @Test func validationCatchesEachPrecondition() throws {
        let source = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: source) }
        let docs = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: docs) }

        // No container → unavailable.
        #expect(VaultMigrator.validationError(source: source, containerDocuments: nil)
            == .iCloudUnavailable)

        // Already-ubiquitous source.
        let container = URL(fileURLWithPath:
            "/Users/x/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/Documents/V")
        #expect(VaultMigrator.validationError(source: container, containerDocuments: docs)
            == .alreadyInICloud)

        // Name collision at the destination.
        let colliding = docs.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.createDirectory(at: colliding, withIntermediateDirectories: true)
        #expect(VaultMigrator.validationError(source: source, containerDocuments: docs)
            == .nameCollision(source.lastPathComponent))

        // Clear path → nil.
        try FileManager.default.removeItem(at: colliding)
        #expect(VaultMigrator.validationError(source: source, containerDocuments: docs) == nil)
    }

    @Test func destinationKeepsVaultName() {
        let docs = URL(fileURLWithPath: "/container/Documents")
        let dest = VaultMigrator.destinationURL(
            for: URL(fileURLWithPath: "/Users/x/My Notes"), containerDocuments: docs)
        #expect(dest.path == "/container/Documents/My Notes")
    }

    // MARK: - Journal + heal

    @Test func journalRoundtripsInIsolatedDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: "gloss-migrator-tests"))
        defer { defaults.removePersistentDomain(forName: "gloss-migrator-tests") }

        #expect(VaultMigrator.readJournal(defaults: defaults) == nil)
        let journal = VaultMigrator.Journal(sourcePath: "/a", destinationPath: "/b")
        VaultMigrator.writeJournal(journal, defaults: defaults)
        #expect(VaultMigrator.readJournal(defaults: defaults) == journal)
        VaultMigrator.clearJournal(defaults: defaults)
        #expect(VaultMigrator.readJournal(defaults: defaults) == nil)
    }

    @Test func healDecisionTable() {
        #expect(VaultMigrator.healAction(sourceExists: false, destinationExists: true) == .adoptDestination)
        #expect(VaultMigrator.healAction(sourceExists: true, destinationExists: false) == .keepSource)
        #expect(VaultMigrator.healAction(sourceExists: true, destinationExists: true) == .abandon)
        #expect(VaultMigrator.healAction(sourceExists: false, destinationExists: false) == .abandon)
    }

    @Test @MainActor func healAdoptsDestinationAndRepairsSettings() throws {
        let defaults = try #require(UserDefaults(suiteName: "gloss-migrator-heal"))
        defer { defaults.removePersistentDomain(forName: "gloss-migrator-heal") }
        let dest = try makeTempDir()   // exists = "move completed"
        defer { try? FileManager.default.removeItem(at: dest) }
        let goneSource = dest.path + "-gone"

        VaultMigrator.writeJournal(
            .init(sourcePath: goneSource, destinationPath: dest.path), defaults: defaults)
        let settings = AppSettings()
        let priorRoot = settings.rootFolderPath
        defer { settings.rootFolderPath = priorRoot }
        settings.rootFolderPath = goneSource

        VaultMigrator.healPendingMigration(settings: settings, defaults: defaults)
        #expect(settings.rootFolderPath == dest.path)
        #expect(VaultMigrator.readJournal(defaults: defaults) == nil)
    }

    // MARK: - RecentsStore.migrateBucket

    @Test @MainActor func migrateBucketRewritesKeysAndPaths() throws {
        // Container must outlive the context (SwiftData does not retain it).
        let container = try ModelContainer(
            for: RecentDocument.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let oldRoot = URL(fileURLWithPath: "/Users/x/Notes")
        let newRoot = URL(fileURLWithPath:
            "/Users/x/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/Documents/Notes")

        context.insert(RecentDocument(
            path: "/Users/x/Notes/a.md", title: "a", documentType: "note",
            vaultPath: RecentsStore.vaultKey(forRoot: oldRoot)))
        context.insert(RecentDocument(
            path: "/Users/x/Notes/sub/b.md", title: "b", documentType: "note",
            isFavorite: true,
            vaultPath: RecentsStore.vaultKey(forRoot: oldRoot)))

        RecentsStore.migrateBucket(oldRoot: oldRoot, newRoot: newRoot, in: context)

        let newKey = RecentsStore.vaultKey(forRoot: newRoot)
        let migrated = try context.fetch(FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.vaultPath == newKey }))
        #expect(migrated.count == 2)
        #expect(Set(migrated.map(\.path)) == [
            newRoot.path + "/a.md",
            newRoot.path + "/sub/b.md",
        ])
        #expect(migrated.contains { $0.isFavorite })

        let oldKey = RecentsStore.vaultKey(forRoot: oldRoot)
        let leftBehind = try context.fetch(FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.vaultPath == oldKey }))
        #expect(leftBehind.isEmpty)
        _ = container   // keep alive to the end of the test
    }
}

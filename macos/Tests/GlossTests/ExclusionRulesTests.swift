import Testing
import Foundation
@testable import Gloss

@Suite("Exclusion Rules")
struct ExclusionRulesTests {

    @Test("Defaults cover dev build artifacts")
    func defaultsCoverDevArtifacts() {
        let rules = ExclusionRules.standard
        for name in ["target", "node_modules", "dist", "DerivedData", "Pods", ".venv", ".git", ".gloss", ".build"] {
            #expect(rules.isExcluded(name), "\(name) should be excluded by default")
        }
        #expect(!rules.isExcluded("docs"))
        #expect(!rules.isExcluded("notes"))
    }

    @Test("Relative path check matches any excluded component")
    func relativePathComponents() {
        let rules = ExclusionRules.standard
        #expect(rules.isExcludedRelativePath("/mulholland/target/debug/build.md"[...]))
        #expect(rules.isExcludedRelativePath("/app/node_modules/pkg/README.md"[...]))
        #expect(!rules.isExcludedRelativePath("/mcg-operations/journal/2026-07-02.md"[...]))
    }

    @Test("Vault config adds and removes names")
    func vaultConfigOverrides() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-rules-\(UUID().uuidString)")
        let glossDir = tmp.appendingPathComponent(".gloss")
        try FileManager.default.createDirectory(at: glossDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let config = #"{ "excludeAdd": ["docs-build"], "excludeRemove": ["dist", ".gloss"] }"#
        try config.write(
            to: glossDir.appendingPathComponent("config.json"),
            atomically: true, encoding: .utf8
        )

        let rules = ExclusionRules.forVault(root: tmp)
        #expect(rules.isExcluded("docs-build"))
        #expect(!rules.isExcluded("dist"))
        // .gloss holds the index database; un-excluding it would feed our own
        // writes back into the watcher.
        #expect(rules.isExcluded(".gloss"))
    }

    @Test("Missing or malformed config falls back to defaults")
    func malformedConfigFallsBack() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-rules-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        #expect(ExclusionRules.forVault(root: tmp) == .standard)

        let glossDir = tmp.appendingPathComponent(".gloss")
        try FileManager.default.createDirectory(at: glossDir, withIntermediateDirectories: true)
        try "not json".write(
            to: glossDir.appendingPathComponent("config.json"),
            atomically: true, encoding: .utf8
        )
        #expect(ExclusionRules.forVault(root: tmp) == .standard)
    }
}

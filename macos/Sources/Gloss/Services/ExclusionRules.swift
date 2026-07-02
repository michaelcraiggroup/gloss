import Foundation

/// Single source of truth for the directory/file names excluded from a vault,
/// consumed by every component that touches the file system: the FSEvents
/// folder watcher, the sidebar tree (`FileTreeNode`), tree reconciliation
/// (`FileTreeModel`), and the link indexer (`LinkIndex`).
///
/// A vault can override the defaults via `<root>/.gloss/config.json`:
///
///     { "excludeAdd": ["docs-build"], "excludeRemove": ["dist"] }
///
/// `.gloss` itself can never be un-excluded: the index database lives there,
/// and watching our own writes would feed events back into indexing.
struct ExclusionRules: Equatable, Sendable {
    /// Names whose subtrees are ignored. Beyond notes-vault noise, this covers
    /// standard build/dependency artifacts so that opening a development
    /// workspace doesn't drown the watcher and indexer — a real-world vault
    /// measured 37k directories, 33k of them inside Rust `target/` alone.
    static let defaultNames: Set<String> = [
        // Vault/system noise
        ".git", ".gloss", ".DS_Store", "Thumbs.db",
        // JS / web
        "node_modules", "dist", "out", "coverage",
        ".next", ".nuxt", ".output", ".svelte-kit", ".astro",
        ".turbo", ".parcel-cache", ".cache",
        // Rust / Swift / JVM / mobile
        "target", "build", ".build", ".swiftpm", "DerivedData",
        ".gradle", "Pods", "Carthage", ".dart_tool",
        // Python / infra
        "__pycache__", ".venv", "venv", ".tox", ".pytest_cache", ".terraform",
        // General
        "vendor",
    ]

    var excludedNames: Set<String>

    /// The built-in defaults with no vault overrides.
    static let standard = ExclusionRules(excludedNames: defaultNames)

    /// Rules for the currently open vault. `FileTreeModel.openFolder` sets
    /// this before arming the watcher or loading the tree; main-actor
    /// consumers (tree loading, reconcile) read it, while background
    /// components (watcher callback, index tasks) receive value copies.
    @MainActor static var current: ExclusionRules = .standard

    /// Whether a single path component is excluded.
    func isExcluded(_ name: String) -> Bool {
        excludedNames.contains(name)
    }

    /// Whether any component of a root-relative path is excluded.
    func isExcludedRelativePath(_ relative: Substring) -> Bool {
        relative.split(separator: "/").contains { excludedNames.contains(String($0)) }
    }

    /// Load the rules for a vault root, applying `.gloss/config.json`
    /// overrides when present. Malformed or absent config yields `.standard`.
    static func forVault(root: URL) -> ExclusionRules {
        let configURL = root
            .appendingPathComponent(".gloss")
            .appendingPathComponent("config.json")
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(VaultConfig.self, from: data) else {
            return .standard
        }
        var names = defaultNames
        names.formUnion(config.excludeAdd ?? [])
        names.subtract(config.excludeRemove ?? [])
        names.insert(".gloss")
        return ExclusionRules(excludedNames: names)
    }

    private struct VaultConfig: Decodable {
        let excludeAdd: [String]?
        let excludeRemove: [String]?
    }
}

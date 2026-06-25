import Foundation
import CoreServices

/// Recursively watches a folder tree for file-system changes using FSEvents,
/// delivering the set of changed paths on the main queue.
///
/// FSEvents is path-based (not file-descriptor-based), so it survives the
/// atomic save-via-rename dance that editors perform — unlike a per-file
/// `DispatchSource` watcher — and it reports changes anywhere in the subtree,
/// not just the immediate directory. It replaces the old 3s polling timer.
///
/// `@unchecked Sendable`: the stream is created/torn down on the main actor
/// (via `FileTreeModel`), while the FSEvents callback fires on `queue`. Teardown
/// (`stop()`/`deinit`) fences any in-flight callback with a `queue.sync` barrier
/// before clearing state, so `handleEvents` never reads a half-cleared closure
/// or touches a `self` that's being deallocated.
final class FolderWatcher: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    private var onChange: (@Sendable ([String]) -> Void)?
    /// Symlink-resolved root, used to strip the prefix before the exclude check.
    private var rootPath: String = ""
    private let queue = DispatchQueue(label: "group.gloss.folderwatcher", qos: .utility)

    /// Path components whose subtrees are ignored (mirrors FileTreeNode.excludedNames).
    private static let excludedComponents: Set<String> = [
        "node_modules", ".git", ".build", ".swiftpm", "__pycache__", ".gloss"
    ]

    /// Start watching `root` and all descendants. Replaces any existing watch.
    /// `onChange` is delivered on the main queue with the changed paths.
    /// Returns `false` if the stream could not be created or started — callers
    /// should fall back (e.g. keep the per-file watcher) rather than assume the
    /// vault is being watched.
    @discardableResult
    func start(root: URL, onChange: @escaping @Sendable ([String]) -> Void) -> Bool {
        stop()

        // FSEvents reports symlink-resolved paths (e.g. /private/var, /private/tmp).
        // Resolve the root so the prefix we strip below actually matches them.
        let resolvedRoot = root.resolvingSymlinksInPath()
        self.rootPath = resolvedRoot.path
        self.onChange = onChange

        let pathsToWatch = [resolvedRoot.path] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer |
            kFSEventStreamCreateFlagUseCFTypes
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, _, eventPaths, _, _ in
                guard let info else { return }
                let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
                guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
                watcher.handleEvents(paths)
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3, // latency (seconds) — coalesce bursts into one callback
            flags
        ) else {
            self.onChange = nil
            self.rootPath = ""
            return false
        }

        FSEventStreamSetDispatchQueue(stream, queue)
        guard FSEventStreamStart(stream) else {
            // Created but couldn't start (e.g. resource pressure): tear down the
            // stream and report failure so the caller keeps a fallback.
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.onChange = nil
            self.rootPath = ""
            return false
        }
        self.stream = stream
        return true
    }

    /// Stop watching the current folder.
    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        // Fence any callback still executing on `queue` before clearing state,
        // so handleEvents never reads a torn closure or a freed self.
        queue.sync { }
        self.onChange = nil
        self.rootPath = ""
    }

    /// Filter excluded subtrees and forward changed paths on the main queue.
    /// Called from the FSEvents callback on `queue`.
    fileprivate func handleEvents(_ paths: [String]) {
        let root = rootPath
        let filtered = paths.filter { path in
            // Only inspect components BELOW the watched root — the root prefix
            // itself may legitimately contain an excluded name (e.g. a vault
            // under .../node_modules/...).
            let relative = path.hasPrefix(root) ? String(path.dropFirst(root.count)) : path
            return !relative.split(separator: "/").contains { Self.excludedComponents.contains(String($0)) }
        }
        guard !filtered.isEmpty, let onChange else { return }
        DispatchQueue.main.async {
            onChange(filtered)
        }
    }

    deinit {
        stop()
    }
}

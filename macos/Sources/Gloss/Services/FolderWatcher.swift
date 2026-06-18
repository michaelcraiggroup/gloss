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
/// (via `FileTreeModel`), while the FSEvents callback fires on `queue`. The
/// callback only reads `onChange` into a local before hopping to main, and
/// FSEvents guarantees no further callbacks once `FSEventStreamStop` returns,
/// so the shared state is effectively confined.
final class FolderWatcher: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    private var onChange: (@Sendable ([String]) -> Void)?
    private let queue = DispatchQueue(label: "group.gloss.folderwatcher", qos: .utility)

    /// Path components whose subtrees are ignored (mirrors FileTreeNode.excludedNames).
    private static let excludedComponents: Set<String> = [
        "node_modules", ".git", ".build", ".swiftpm", "__pycache__", ".gloss"
    ]

    /// Start watching `root` and all descendants. Replaces any existing watch.
    /// `onChange` is delivered on the main queue with deduplicated changed paths.
    func start(root: URL, onChange: @escaping @Sendable ([String]) -> Void) {
        stop()
        self.onChange = onChange

        let pathsToWatch = [root.standardizedFileURL.path] as CFArray
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
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    /// Stop watching the current folder.
    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        self.onChange = nil
    }

    /// Filter excluded subtrees and forward changed paths on the main queue.
    /// Called from the FSEvents callback on `queue`.
    fileprivate func handleEvents(_ paths: [String]) {
        let filtered = paths.filter { path in
            !path.split(separator: "/").contains { Self.excludedComponents.contains(String($0)) }
        }
        guard !filtered.isEmpty, let onChange else { return }
        DispatchQueue.main.async {
            onChange(filtered)
        }
    }

    deinit {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}

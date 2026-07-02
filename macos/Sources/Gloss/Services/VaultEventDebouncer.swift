import Foundation

/// Coalesces bursts of file-system change paths into batched deliveries.
///
/// FSEvents already coalesces at the stream level (0.3s), but sustained churn
/// — builds, git operations, agent sessions writing into the vault — still
/// yields several callbacks per second, and each delivery costs a tree
/// reconcile plus index work. This debouncer flushes after `quietInterval`
/// with no new events, capped by `maxLatency` so a continuous stream still
/// delivers periodically instead of starving forever.
@MainActor
final class VaultEventDebouncer {
    private(set) var pending: Set<String> = []
    private var flushTask: Task<Void, Never>?
    private var oldestPendingAt: ContinuousClock.Instant?
    private let quietInterval: Duration
    private let maxLatency: Duration
    private let onFlush: @MainActor ([String]) -> Void

    init(
        quietInterval: Duration = .milliseconds(400),
        maxLatency: Duration = .milliseconds(1500),
        onFlush: @escaping @MainActor ([String]) -> Void
    ) {
        self.quietInterval = quietInterval
        self.maxLatency = maxLatency
        self.onFlush = onFlush
    }

    /// Merge new paths into the pending batch and (re)schedule a flush.
    func add(_ paths: [String]) {
        pending.formUnion(paths)
        let now = ContinuousClock.now
        if oldestPendingAt == nil { oldestPendingAt = now }

        flushTask?.cancel()
        let age = now - (oldestPendingAt ?? now)
        let delay = min(quietInterval, max(.zero, maxLatency - age))
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// Deliver the pending batch immediately (no-op when empty).
    func flush() {
        flushTask?.cancel()
        flushTask = nil
        oldestPendingAt = nil
        guard !pending.isEmpty else { return }
        let batch = Array(pending)
        pending.removeAll()
        onFlush(batch)
    }

    /// Drop pending paths and cancel any scheduled flush.
    func cancel() {
        flushTask?.cancel()
        flushTask = nil
        pending.removeAll()
        oldestPendingAt = nil
    }
}

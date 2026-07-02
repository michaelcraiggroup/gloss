import Testing
import Foundation
@testable import Gloss

@Suite("Vault Event Debouncer")
struct VaultEventDebouncerTests {

    @Test("A burst coalesces into one deduplicated flush")
    @MainActor
    func burstCoalesces() async throws {
        var flushes: [[String]] = []
        let debouncer = VaultEventDebouncer(
            quietInterval: .milliseconds(100),
            maxLatency: .milliseconds(500)
        ) { flushes.append($0.sorted()) }

        debouncer.add(["/v/a.md", "/v/b.md"])
        debouncer.add(["/v/b.md", "/v/c.md"])
        debouncer.add(["/v/a.md"])

        try await Task.sleep(for: .milliseconds(300))
        #expect(flushes == [["/v/a.md", "/v/b.md", "/v/c.md"]])
    }

    @Test("Continuous churn still flushes via the max-latency cap")
    @MainActor
    func maxLatencyCapFlushes() async throws {
        var flushCount = 0
        let debouncer = VaultEventDebouncer(
            quietInterval: .milliseconds(200),
            maxLatency: .milliseconds(400)
        ) { _ in flushCount += 1 }

        // Keep adding faster than the quiet interval for ~1s; without the
        // cap this would starve forever.
        for i in 0..<10 {
            debouncer.add(["/v/file-\(i).md"])
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(flushCount >= 1)
        #expect(flushCount <= 3)
    }

    @Test("Cancel drops pending paths")
    @MainActor
    func cancelDropsPending() async throws {
        var flushes = 0
        let debouncer = VaultEventDebouncer(
            quietInterval: .milliseconds(100),
            maxLatency: .milliseconds(300)
        ) { _ in flushes += 1 }

        debouncer.add(["/v/a.md"])
        debouncer.cancel()
        try await Task.sleep(for: .milliseconds(250))
        #expect(flushes == 0)
        #expect(debouncer.pending.isEmpty)
    }
}

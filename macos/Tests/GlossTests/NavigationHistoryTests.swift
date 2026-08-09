import Foundation
import Testing
@testable import Gloss

@Suite("NavigationHistory")
@MainActor
struct NavigationHistoryTests {
    private let a = URL(fileURLWithPath: "/v/a.md")
    private let b = URL(fileURLWithPath: "/v/b.md")

    @Test func overviewIsReachableByBackingOutOfTheFirstDocument() {
        let history = NavigationHistory()
        history.record(old: nil, new: a)          // overview → a
        #expect(history.canGoBack)
        #expect(history.goBack(from: a) == .overview)
    }

    @Test func traversalIsNotReRecorded() {
        let history = NavigationHistory()
        history.record(old: nil, new: a)          // overview → a
        history.record(old: a, new: b)            // a → b

        let back = history.goBack(from: b)        // → a
        #expect(back == .document(a))
        history.record(old: b, new: a)            // the recorder observing it

        // The regression this suite pins: without the latch, the recorder
        // re-recorded every Back as a new navigation — the back stack
        // refilled itself and forward died. After one Back, forward must
        // still work and back must reach the overview.
        #expect(history.canGoForward)
        #expect(history.goForward(from: a) == .document(b))
        history.record(old: a, new: b)

        #expect(history.goBack(from: b) == .document(a))
        history.record(old: b, new: a)
        #expect(history.goBack(from: a) == .overview)
        history.record(old: a, new: nil)
        #expect(!history.canGoBack)
    }

    @Test func closeVaultIsNotANavigationEvent() {
        let history = NavigationHistory()
        history.record(old: nil, new: a)
        history.record(old: a, new: nil)          // Close Vault nils selection
        // The close itself must not enter history (Back would select a file
        // of a closed vault) — one entry remains: the overview → a step.
        #expect(history.goBack(from: nil) == .overview)
    }

    @Test func forwardFromOverviewReturnsToTheDocument() {
        let history = NavigationHistory()
        history.record(old: nil, new: a)
        #expect(history.goBack(from: a) == .overview)
        history.record(old: a, new: nil)
        #expect(history.goForward(from: nil) == .document(a))
        history.record(old: nil, new: a)
        #expect(!history.canGoForward)
    }

    @Test func resetClearsEverything() {
        let history = NavigationHistory()
        history.record(old: nil, new: a)
        history.record(old: a, new: b)
        history.reset()
        #expect(!history.canGoBack)
        #expect(!history.canGoForward)
        #expect(history.goBack(from: b) == nil)
    }
}

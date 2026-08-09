import Foundation

/// Tracks file navigation history for back/forward browsing.
///
/// Two load-bearing choices (both from the 2026-08-09 Mac/iPhone parity pass):
///
/// **The vault overview is a real place.** Stacks hold `URL?` — `nil` is the
/// overview (no document selected) — so backing out of the first document
/// lands on the overview instead of dead-ending, browser-style.
///
/// **Traversal is latched, not timed.** The recorder (`record(old:new:)`)
/// runs from SwiftUI's `onChange`, which fires on the NEXT view update — a
/// `defer`-cleared flag inside goBack/goForward is already false by then, so
/// every Back was re-recorded as a fresh navigation: the back stack refilled
/// itself, forward cleared, and the bottom of history was unreachable
/// ("cycles forever"). The latch stays set until the recorder observes the
/// traversal and clears it.
@Observable
@MainActor
final class NavigationHistory {
    enum Destination: Equatable {
        case overview
        case document(URL)

        init(_ url: URL?) {
            self = url.map(Self.document) ?? .overview
        }

        /// The URL to select, or nil for the overview.
        var url: URL? {
            if case .document(let url) = self { return url }
            return nil
        }
    }

    private var backStack: [URL?] = []
    private var forwardStack: [URL?] = []
    private var isTraversing = false

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    /// Feed every `currentFileURL` change here (both branches — document and
    /// nil). A change caused by goBack/goForward clears the latch and records
    /// nothing. A change to `nil` outside traversal (Close Vault) is not a
    /// navigation event. Everything else pushes the departed place — including
    /// the overview as `nil` — onto the back stack.
    func record(old: URL?, new: URL?) {
        if isTraversing {
            isTraversing = false
            return
        }
        guard new != nil else { return }
        backStack.append(old)
        forwardStack.removeAll()
    }

    /// Go back. Returns the destination to apply, or nil when at the bottom.
    func goBack(from current: URL?) -> Destination? {
        guard !backStack.isEmpty else { return nil }
        isTraversing = true
        forwardStack.append(current)
        return Destination(backStack.removeLast())
    }

    /// Go forward. Returns the destination to apply, or nil at the top.
    func goForward(from current: URL?) -> Destination? {
        guard !forwardStack.isEmpty else { return nil }
        isTraversing = true
        backStack.append(current)
        return Destination(forwardStack.removeLast())
    }

    /// Vault switches and closes invalidate cross-vault entries.
    func reset() {
        backStack.removeAll()
        forwardStack.removeAll()
        isTraversing = false
    }
}

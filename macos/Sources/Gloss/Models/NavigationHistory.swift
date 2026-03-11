import Foundation

/// Tracks file navigation history for back/forward browsing.
@Observable
@MainActor
final class NavigationHistory {
    private var backStack: [URL] = []
    private var forwardStack: [URL] = []
    private var isNavigating = false

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    /// Record a navigation to a new file. Clears forward stack.
    func navigate(to url: URL, from current: URL?) {
        guard !isNavigating else { return }
        if let current {
            backStack.append(current)
        }
        forwardStack.removeAll()
    }

    /// Go back to the previous file. Returns the URL to navigate to.
    func goBack(from current: URL?) -> URL? {
        guard let destination = backStack.popLast() else { return nil }
        isNavigating = true
        defer { isNavigating = false }
        if let current {
            forwardStack.append(current)
        }
        return destination
    }

    /// Go forward. Returns the URL to navigate to.
    func goForward(from current: URL?) -> URL? {
        guard let destination = forwardStack.popLast() else { return nil }
        isNavigating = true
        defer { isNavigating = false }
        if let current {
            backStack.append(current)
        }
        return destination
    }
}

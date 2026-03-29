import Foundation

/// Identifies a native SwiftUI view that can be spotlighted during a walkthrough.
enum SpotlightTarget: String, CaseIterable, Sendable {
    case sidebarTagsSection
    case sidebarSearchScope
    case toolbarInspectorToggle
    case toolbarEditMode
    case toolbarFavorite
    case inspectorTags
    case inspectorTOC
    case inspectorBacklinks
}

/// A single step in a walkthrough — either native (SwiftUI) or web (WKWebView).
enum WalkthroughStep: Sendable {
    case web(WebStep)
    case native(NativeStep)

    var id: String {
        switch self {
        case .web(let step): step.id
        case .native(let step): step.id
        }
    }
}

/// A step rendered by the Rabble Guide SDK inside WKWebView.
struct WebStep: Sendable {
    let id: String
    let type: String          // "spotlight", "content"
    let target: String?       // CSS selector (for spotlight)
    let content: String       // Markdown
    let placement: String     // "top", "bottom", "center", etc.

    /// JSON representation for passing to the JS SDK.
    var jsonObject: [String: Any] {
        var obj: [String: Any] = [
            "type": type,
            "content": content,
            "placement": placement,
        ]
        if let target { obj["target"] = target }
        return obj
    }
}

/// A step rendered by NativeSpotlightOverlay on a SwiftUI view.
struct NativeStep: Sendable, Equatable {
    let id: String
    let target: SpotlightTarget
    let content: String       // Plain text or simple markdown
    let placement: String     // "top", "bottom", "leading", "trailing"
}

/// A complete walkthrough guide — a sequence of steps.
struct WalkthroughGuide: Sendable {
    let id: String
    let name: String
    let version: Int
    let steps: [WalkthroughStep]
}

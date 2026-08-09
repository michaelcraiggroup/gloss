import SwiftUI

/// View modifier that captures a view's frame and writes it directly to GlossGuideService.
/// Uses environment injection instead of PreferenceKey so it works across view hierarchy
/// boundaries (e.g., ToolbarItem views that don't propagate preferences to parent).
struct SpotlightTargetModifier: ViewModifier {
    let target: SpotlightTarget
    /// Optional on purpose: iOS compiles shared views that carry spotlight
    /// anchors (InspectorView) but never injects GlossGuideService — guides
    /// are macOS-only in v1. The non-optional form FATALS on first appear
    /// ("No Observable object of type GlossGuideService found"); the
    /// optional form makes the anchor inert instead. Found by the 2026-08-08
    /// two-device QA: tapping the iOS inspector froze the app.
    @Environment(GlossGuideService.self) private var guideService: GlossGuideService?

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        guideService?.spotlightFrames[target] = geo.frame(in: .global)
                    }
            }
        )
    }
}

extension View {
    /// Register this view as a spotlight target for walkthroughs.
    func spotlightTarget(_ target: SpotlightTarget) -> some View {
        self.modifier(SpotlightTargetModifier(target: target))
    }
}

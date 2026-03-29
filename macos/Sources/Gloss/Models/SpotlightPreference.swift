import SwiftUI

/// View modifier that captures a view's frame and writes it directly to GlossGuideService.
/// Uses environment injection instead of PreferenceKey so it works across view hierarchy
/// boundaries (e.g., ToolbarItem views that don't propagate preferences to parent).
struct SpotlightTargetModifier: ViewModifier {
    let target: SpotlightTarget
    @Environment(GlossGuideService.self) private var guideService

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        guideService.spotlightFrames[target] = geo.frame(in: .global)
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

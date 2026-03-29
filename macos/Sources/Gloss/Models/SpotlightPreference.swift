import SwiftUI

/// Preference key that collects spotlight target frames from annotated views.
struct SpotlightPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [SpotlightTarget: CGRect] = [:]

    static func reduce(value: inout [SpotlightTarget: CGRect], nextValue: () -> [SpotlightTarget: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    /// Register this view as a spotlight target for walkthroughs.
    func spotlightTarget(_ target: SpotlightTarget) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: SpotlightPreferenceKey.self,
                    value: [target: geo.frame(in: .global)]
                )
            }
        )
    }
}

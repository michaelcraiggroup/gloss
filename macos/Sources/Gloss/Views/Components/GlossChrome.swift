import SwiftUI

// MARK: - Gloss sheen

private struct GlossSheenModifier: ViewModifier {
    var strength: Double
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            LinearGradient(
                colors: [Color.white.opacity(strength), Color.white.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
    }
}

extension View {
    /// The brand's signature "gloss" — a subtle top-edge highlight over a filled surface.
    func glossSheen(strength: Double = 0.22) -> some View {
        modifier(GlossSheenModifier(strength: strength))
    }
}

// MARK: - Branded sidebar header

/// Gloss wordmark + "by Off-Leash" trust-mark, pinned atop the sidebar via
/// `.safeAreaInset`. The leading inset clears the window traffic lights (the frame
/// uses a hidden title bar).
struct GlossSidebarHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Gloss")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.glossChromeInk(colorScheme))
                Text("BY OFF-LEASH")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color.glossSheen(colorScheme))
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 74)
        .padding(.trailing, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.glossChromeSidebar(colorScheme))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.glossChromeInk(colorScheme).opacity(colorScheme == .dark ? 0.0 : 0.08))
                .frame(height: 1)
        }
    }
}

// MARK: - Detail content frame

/// The detail-area chrome: a warm/navy backdrop, and in light mode a floating white
/// "sheet" (padding + rounded card + soft shadow) so the document reads as paper on a
/// desk. In dark mode the content meets the navy chrome edge-to-edge (one surface).
struct GlossContentFrame: ViewModifier {
    let scheme: ColorScheme
    let sheeted: Bool

    func body(content: Content) -> some View {
        content
            .modifier(GlossSheet(enabled: sheeted))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.glossChromeBg(scheme))
    }
}

private struct GlossSheet: ViewModifier {
    let enabled: Bool
    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .background(Color(gloss: 0xFBFBFB)) // matches CSS light --bg behind the transparent web view
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 3)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        } else {
            content
        }
    }
}

extension View {
    /// Wrap the document detail in the themed backdrop (+ floating sheet in light).
    func glossContentFrame(scheme: ColorScheme, sheeted: Bool) -> some View {
        modifier(GlossContentFrame(scheme: scheme, sheeted: sheeted))
    }
}


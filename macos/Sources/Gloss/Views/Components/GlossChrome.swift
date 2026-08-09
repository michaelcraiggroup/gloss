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
    /// Vault mode: the open vault's identity replaces the wordmark, and the
    /// whole header is the doorway back to the library (iOS parity: the
    /// books button at the top of the sidebar). nil = library mode, which
    /// keeps the wordmark. The affordance lives IN the sidebar — hidden
    /// with it — never in the window's toolbar.
    var vaultName: String?
    var onShowLibrary: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            if let vaultName {
                Button {
                    onShowLibrary?()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "books.vertical")
                            .foregroundStyle(Color.glossSheen(colorScheme))
                        Text(vaultName)
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.glossChromeInk(colorScheme))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Vault Library")
                .accessibilityLabel("Show Vault Library")
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Gloss")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.glossChromeInk(colorScheme))
                    Text("BY OFF-LEASH")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Color.glossSheen(colorScheme))
                }
            }
            Spacer(minLength: 0)
        }
        // The wordmark keeps its historical clearance; the vault row sits
        // flush with the sidebar's content edge (left-justified icon).
        .padding(.leading, vaultName != nil ? 16 : 74)
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

// MARK: - Sidebar section hierarchy

struct GlossShelfHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.7)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}

extension View {
    /// Header styling for a secondary sidebar section — quieter than the vault.
    func glossShelfHeader() -> some View {
        modifier(GlossShelfHeaderStyle())
    }
}

/// A shelf header that IS the collapse toggle: title + always-visible
/// rotating chevron, flipping a persisted binding. Built by hand because
/// `Section(isExpanded:)` never wires its disclosure to custom header views
/// in this sidebar (verified against defaults — clicks never reached the
/// binding). Rows are gated by the caller; the header itself persists, per
/// the #61 section-lifetime rule.
struct ShelfToggleHeader: View {
    let title: String
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Text(title).glossShelfHeader()
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isExpanded ? "Hide" : "Show") \(title)")
    }
}

/// Hairline marking where the vault's documents end and the shelves begin.
/// Lives inside the first shelf header (rather than in a section of its own) so
/// no sidebar section can appear or disappear under the cursor — see the
/// section-lifetime note in FavoritesSection (#61).
struct GlossShelfDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(Color.glossChromeInk(colorScheme).opacity(colorScheme == .dark ? 0.20 : 0.13))
            .frame(height: 1)
            .padding(.top, 6)
            .padding(.bottom, 2)
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


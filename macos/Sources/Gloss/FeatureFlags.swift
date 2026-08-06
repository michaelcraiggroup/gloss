import Foundation

/// Build-time switches for features that exist in the codebase but aren't
/// shipping yet.
///
/// Turning one back on restores every entry point at once — the implementation
/// stays compiled and tested either way, so a shelved feature can't rot while
/// it waits. Prefer a flag here over commenting code out.
enum GlossFeatures {
    /// Vault Graph (⌥⌘G) — the D3 force-directed link map (`GraphView`,
    /// `GraphService`, `graph.html`, `LinkDatabase`'s graph queries).
    ///
    /// Off: the view works, but it hasn't earned a place in the product yet and
    /// shipping it would make a Pro promise of a feature nobody has needed. See
    /// gloss#12. Flip to `true` to bring back the View-menu item, the sidebar
    /// toolbar button, the detail-view route, and the paywall's feature row.
    static let vaultGraph = false
}

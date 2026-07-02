import SwiftUI

extension Color {
    /// Brand amber accent (#B45309) — the deep "fill" tone that stays readable with
    /// white text on buttons and chips. Mirrors `--accent` in gloss-theme.css. The
    /// reading surface uses a brighter gold (#FBBF24) for links via CSS, where the
    /// contrast against dark navy is ideal.
    static let glossAccent = Color(red: 180.0 / 255.0, green: 83.0 / 255.0, blue: 9.0 / 255.0)

    /// Build a Color from a 24-bit hex value (0xRRGGBB).
    init(gloss hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }

    // MARK: - Window chrome — "Reading Desk" (light) / "Night Owl" (dark)
    //
    // Driven by the effective `ColorScheme` (which `.preferredColorScheme` sets from
    // the appearance setting, including the system case, so the chrome follows the OS
    // live). The dark values match the reading theme's CSS variables so the chrome is
    // continuous with the rendered content.

    /// Window / detail backdrop. Light = warm parchment "desk"; dark = Night Owl navy
    /// matched exactly to CSS `--bg` (#011627) so navy chrome meets navy content with
    /// no visible seam.
    static func glossChromeBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(gloss: 0x011627) : Color(gloss: 0xF4ECE0)
    }

    /// Sidebar panel — a touch deeper than the desk in light so it reads as a distinct
    /// panel; a lifted navy in dark (echoes CSS `--code-bg`).
    static func glossChromeSidebar(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(gloss: 0x04202F) : Color(gloss: 0xEDE3D2)
    }

    /// The unifying sheen accent. Light = deep amber (#B45309); dark = bright gold
    /// (#FBBF24) — mirrors CSS `--accent` / `--accent-light`.
    static func glossSheen(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(gloss: 0xFBBF24) : Color(gloss: 0xB45309)
    }

    /// Primary text tone on the chrome. Light = warm near-black; dark = the reading
    /// theme foreground (#d6deeb).
    static func glossChromeInk(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(gloss: 0xD6DEEB) : Color(gloss: 0x2A2018)
    }
}

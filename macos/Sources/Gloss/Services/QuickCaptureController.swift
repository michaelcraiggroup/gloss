import SwiftUI
import AppKit

/// A panel that can accept keyboard focus while borderless / non-activating,
/// so the capture field works without bringing all of Gloss forward.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Drives "quick capture": a floating panel, summoned by shoving the cursor into
/// a configurable screen corner (à la macOS Quick Note) or from the menu bar,
/// whose text appends to today's daily note without leaving the frontmost app.
///
/// The trigger is pure cursor-position polling (`NSEvent.mouseLocation`) — no
/// entitlement and no Accessibility permission, unlike a global keyboard hotkey.
@MainActor
final class QuickCaptureController: NSObject, ObservableObject, NSWindowDelegate {
    private weak var settings: AppSettings?
    private var onCaptured: ((URL) -> Void)?

    private var timer: Timer?
    private var panel: NSPanel?
    /// Edge-trigger latch: fire once on entry, re-arm only after leaving the corner.
    private var armed = true

    private let triggerRadius: CGFloat = 4     // how close to the corner counts as "in"
    private let exitRadius: CGFloat = 50       // must leave this zone before re-arming
    private let panelSize = CGSize(width: 400, height: 190)

    // MARK: - Lifecycle

    /// Begin watching the hot corner. `onCaptured` fires (main thread) with the
    /// written note's URL so the app can refresh the tree / re-index.
    func start(settings: AppSettings, onCaptured: @escaping (URL) -> Void) {
        self.settings = settings
        self.onCaptured = onCaptured
        setEnabled(settings.quickCaptureEnabled)
    }

    func setEnabled(_ enabled: Bool) {
        timer?.invalidate()
        timer = nil
        guard enabled else { return }
        let t = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(t, forMode: .common)   // keep firing during menu tracking / drags
        timer = t
    }

    // MARK: - Hot-corner polling

    private func poll() {
        guard let settings, panel == nil else { return }
        let mouse = NSEvent.mouseLocation
        let corner = settings.screenCorner
        if let screen = NSScreen.screens.first(where: {
            Self.isInCorner(mouse, screenFrame: $0.frame, corner: corner, radius: triggerRadius)
        }) {
            if armed { armed = false; showPanel(corner: corner, on: screen) }
        } else if !NSScreen.screens.contains(where: {
            Self.isInCorner(mouse, screenFrame: $0.frame, corner: corner, radius: exitRadius)
        }) {
            armed = true
        }
    }

    /// Whether `mouse` sits within `radius` of `corner` of `screenFrame` (a small
    /// corner box). Pure — unit-tested.
    nonisolated static func isInCorner(_ mouse: CGPoint, screenFrame: CGRect, corner: ScreenCorner, radius: CGFloat) -> Bool {
        let c = corner.point(in: screenFrame)
        return abs(mouse.x - c.x) <= radius && abs(mouse.y - c.y) <= radius
    }

    // MARK: - Panel

    /// Show the capture panel. With no corner/screen (menu-bar path) it lands at
    /// the configured corner of the main screen.
    func showPanel(corner: ScreenCorner? = nil, on screen: NSScreen? = nil) {
        if let panel { panel.makeKeyAndOrderFront(nil); return }
        guard let settings else { return }
        let hasVault = !settings.rootFolderPath.isEmpty
        let host = NSHostingController(rootView: QuickCaptureView(
            hasVault: hasVault,
            onSubmit: { [weak self] text in self?.capture(text); self?.closePanel() },
            onCancel: { [weak self] in self?.closePanel() }
        ))

        let usedScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        let frame = panelFrame(corner: corner ?? settings.screenCorner,
                               visibleFrame: usedScreen?.visibleFrame ?? .zero)

        let p = KeyablePanel(contentRect: frame,
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: false)
        p.contentViewController = host
        p.setFrame(frame, display: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.isMovableByWindowBackground = true
        p.hidesOnDeactivate = false
        p.delegate = self
        panel = p
        p.makeKeyAndOrderFront(nil)
    }

    /// Panel origin inset from `corner` within a screen's visible frame.
    private func panelFrame(corner: ScreenCorner, visibleFrame vf: CGRect) -> CGRect {
        let inset: CGFloat = 16
        let x: CGFloat
        let y: CGFloat
        switch corner {
        case .bottomLeft:  x = vf.minX + inset;                       y = vf.minY + inset
        case .bottomRight: x = vf.maxX - panelSize.width - inset;     y = vf.minY + inset
        case .topLeft:     x = vf.minX + inset;                       y = vf.maxY - panelSize.height - inset
        case .topRight:    x = vf.maxX - panelSize.width - inset;     y = vf.maxY - panelSize.height - inset
        }
        return CGRect(origin: CGPoint(x: x, y: y), size: panelSize)
    }

    func closePanel() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        armed = true
    }

    /// Dismiss when the user clicks away (mirrors Spotlight / Quick Note).
    func windowDidResignKey(_ notification: Notification) {
        closePanel()
    }

    // MARK: - Capture

    private func capture(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let settings, let url = settings.dailyNoteURL() else { return }
        let dir = url.deletingLastPathComponent()
        let existed = FileManager.default.fileExists(atPath: url.path)
        let existing = existed
            ? ((try? String(contentsOf: url, encoding: .utf8)) ?? "")
            : AppSettings.dailyNoteTemplate(title: url.deletingPathExtension().lastPathComponent)

        let timestamp = Self.timeFormatter.string(from: Date())
        let updated = Self.appendedContent(existing: existing, capture: trimmed, timestamp: timestamp)
        do {
            if !existed {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            try updated.write(to: url, atomically: true, encoding: .utf8)
            onCaptured?(url)
        } catch {
            // Write failed silently — capture is best-effort.
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    /// Append a timestamped bullet, guaranteeing a newline boundary. Pure — unit-tested.
    nonisolated static func appendedContent(existing: String, capture: String, timestamp: String) -> String {
        let trimmedCapture = capture.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = (existing.isEmpty || existing.hasSuffix("\n")) ? existing : existing + "\n"
        return base + "- \(timestamp) \(trimmedCapture)\n"
    }
}

import SwiftUI

/// Full-window overlay that spotlights a native SwiftUI view during a walkthrough step.
/// Reads the current native step from GlossGuideService and renders a backdrop with cutout
/// plus a popover card with content, progress, and navigation controls.
///
/// Uses a GeometryReader to convert global spotlight frames to overlay-local coordinates,
/// which is essential for toolbar items that live outside the content area.
struct NativeSpotlightOverlay: View {
    @Environment(GlossGuideService.self) private var guideService

    var body: some View {
        GeometryReader { overlayGeo in
            let overlayOrigin = overlayGeo.frame(in: .global).origin
            if let step = guideService.currentNativeStep,
               let globalFrame = guideService.spotlightFrames[step.target] {
                let frame = localFrame(from: globalFrame, overlayOrigin: overlayOrigin)
                ZStack {
                    // Backdrop with cutout
                    SpotlightCutoutShape(hole: frame.insetBy(dx: -8, dy: -8))
                        .fill(.black.opacity(0.5))
                        .ignoresSafeArea()
                        .onTapGesture {
                            guideService.skip()
                        }

                    // Popover card
                    GuidePopover(
                        content: step.content,
                        progress: guideService.progress,
                        onContinue: { guideService.advance() },
                        onSkip: { guideService.skip() }
                    )
                    .position(popoverPosition(for: frame, placement: step.placement,
                                              overlaySize: overlayGeo.size))
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: step.id)
                .onExitCommand {
                    guideService.skip()
                }
            }
        }
    }

    /// Convert a global frame to overlay-local coordinates.
    private func localFrame(from globalFrame: CGRect, overlayOrigin: CGPoint) -> CGRect {
        CGRect(
            x: globalFrame.origin.x - overlayOrigin.x,
            y: globalFrame.origin.y - overlayOrigin.y,
            width: globalFrame.width,
            height: globalFrame.height
        )
    }

    private func popoverPosition(for targetFrame: CGRect, placement: String,
                                 overlaySize: CGSize) -> CGPoint {
        let cardWidth: CGFloat = 280
        let offset: CGFloat = 16

        // Clamp x so the popover stays within the overlay bounds
        let rawX: CGFloat
        let y: CGFloat

        switch placement {
        case "top":
            rawX = targetFrame.midX
            y = targetFrame.minY - offset - 60
        case "bottom":
            rawX = targetFrame.midX
            y = targetFrame.maxY + offset + 60
        case "leading":
            rawX = targetFrame.minX - offset - cardWidth / 2
            y = targetFrame.midY
        case "trailing":
            rawX = targetFrame.maxX + offset + cardWidth / 2
            y = targetFrame.midY
        default:
            rawX = targetFrame.midX
            y = targetFrame.maxY + offset + 60
        }

        // Keep popover within horizontal bounds
        let halfCard = cardWidth / 2
        let clampedX = min(max(rawX, halfCard + 16), overlaySize.width - halfCard - 16)

        return CGPoint(x: clampedX, y: y)
    }
}

/// Card displaying step content with navigation controls.
struct GuidePopover: View {
    let content: String
    let progress: (current: Int, total: Int)
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(content))
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("\(progress.current) of \(progress.total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Skip") {
                    onSkip()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)

                Button {
                    onContinue()
                } label: {
                    Text(progress.current == progress.total ? "Done" : "Next")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 280)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        }
        .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.18))
        .colorScheme(.light)
    }
}

/// Shape that fills the entire rect except for a rounded-rect hole (spotlight cutout).
struct SpotlightCutoutShape: Shape {
    let hole: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRoundedRect(
            in: hole,
            cornerSize: CGSize(width: 8, height: 8)
        )
        return path
    }
}

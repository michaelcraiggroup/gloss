import SwiftUI

/// Full-window overlay that spotlights a native SwiftUI view during a walkthrough step.
/// Reads the current native step from GlossGuideService and renders a backdrop with cutout
/// plus a popover card with content, progress, and navigation controls.
struct NativeSpotlightOverlay: View {
    @Environment(GlossGuideService.self) private var guideService

    var body: some View {
        if let step = guideService.currentNativeStep,
           let frame = guideService.spotlightFrames[step.target] {
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
                .position(popoverPosition(for: frame, placement: step.placement))
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: step.id)
            .onExitCommand {
                guideService.skip()
            }
        }
    }

    private func popoverPosition(for targetFrame: CGRect, placement: String) -> CGPoint {
        let cardWidth: CGFloat = 280
        let offset: CGFloat = 16

        switch placement {
        case "top":
            return CGPoint(
                x: targetFrame.midX,
                y: targetFrame.minY - offset - 60
            )
        case "bottom":
            return CGPoint(
                x: targetFrame.midX,
                y: targetFrame.maxY + offset + 60
            )
        case "leading":
            return CGPoint(
                x: targetFrame.minX - offset - cardWidth / 2,
                y: targetFrame.midY
            )
        case "trailing":
            return CGPoint(
                x: targetFrame.maxX + offset + cardWidth / 2,
                y: targetFrame.midY
            )
        default:
            return CGPoint(
                x: targetFrame.midX,
                y: targetFrame.maxY + offset + 60
            )
        }
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

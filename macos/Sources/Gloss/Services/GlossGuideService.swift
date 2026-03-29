import Foundation

/// Central coordinator for feature walkthroughs.
/// Sequences steps across two renderers: Rabble Guide SDK (web) and NativeSpotlightOverlay (SwiftUI).
@Observable
@MainActor
final class GlossGuideService {
    var activeGuide: WalkthroughGuide?
    var currentStepIndex: Int = 0
    var isWebSDKReady: Bool = false

    /// The current native step, if any. NativeSpotlightOverlay observes this.
    var currentNativeStep: NativeStep? {
        guard let guide = activeGuide,
              currentStepIndex < guide.steps.count,
              case .native(let step) = guide.steps[currentStepIndex]
        else { return nil }
        return step
    }

    /// The current web step, if any.
    var currentWebStep: WebStep? {
        guard let guide = activeGuide,
              currentStepIndex < guide.steps.count,
              case .web(let step) = guide.steps[currentStepIndex]
        else { return nil }
        return step
    }

    var isActive: Bool { activeGuide != nil }

    var progress: (current: Int, total: Int) {
        (currentStepIndex + 1, activeGuide?.steps.count ?? 0)
    }

    /// When true, the next `stop` event from the JS SDK is suppressed (it was triggered
    /// programmatically by `advance()`, not by the user dismissing the guide).
    @ObservationIgnored
    private var suppressNextWebStop = false

    // MARK: - Completion Tracking

    @ObservationIgnored
    private let completedKey = "glossCompletedGuides"

    private var completedGuides: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: completedKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: completedKey)
        }
    }

    func isCompleted(_ guideId: String) -> Bool {
        completedGuides.contains(guideId)
    }

    // MARK: - Guide Lifecycle

    func start(guide: WalkthroughGuide) {
        // Stop any in-progress guide first
        if activeGuide != nil {
            NotificationCenter.default.post(name: .glossGuideStopWeb, object: nil)
        }
        activeGuide = guide
        currentStepIndex = 0
        dispatchCurrentStep()
    }

    func advance() {
        guard let guide = activeGuide else { return }

        // Stop any active web step — suppress the resulting SDK stop event
        // so it doesn't trigger skip() and kill the entire guide.
        if currentWebStep != nil {
            suppressNextWebStop = true
            NotificationCenter.default.post(name: .glossGuideStopWeb, object: nil)
        }

        currentStepIndex += 1

        if currentStepIndex >= guide.steps.count {
            complete()
        } else {
            dispatchCurrentStep()
        }
    }

    func skip() {
        if currentWebStep != nil {
            NotificationCenter.default.post(name: .glossGuideStopWeb, object: nil)
        }
        complete()
    }

    /// Called when the JS SDK reports a web step completed.
    func handleWebStepComplete() {
        advance()
    }

    /// Called when the JS SDK fires a stop event. Ignores programmatic stops
    /// triggered by `advance()` — only acts on user-initiated dismissals.
    func handleWebStopped() {
        if suppressNextWebStop {
            suppressNextWebStop = false
            return
        }
        skip()
    }

    /// Called when the WKWebView signals the SDK is initialized.
    func handleWebSDKReady() {
        isWebSDKReady = true
        // If we were waiting for SDK to be ready, re-dispatch the current step
        if let step = currentWebStep {
            dispatchWebStep(step)
        }
    }

    // MARK: - Private

    private func dispatchCurrentStep() {
        guard let guide = activeGuide, currentStepIndex < guide.steps.count else { return }

        switch guide.steps[currentStepIndex] {
        case .native:
            break // NativeSpotlightOverlay reads currentNativeStep reactively
        case .web(let step):
            // Always dispatch — the JS retry loop handles SDK not yet ready.
            // If SDK hasn't signaled ready yet, handleWebSDKReady() will re-dispatch.
            dispatchWebStep(step)
        }
    }

    private func dispatchWebStep(_ step: WebStep) {
        NotificationCenter.default.post(
            name: .glossGuideDispatchWeb,
            object: step
        )
    }

    private func complete() {
        if let guide = activeGuide {
            completedGuides.insert(guide.id)
        }
        activeGuide = nil
        currentStepIndex = 0
    }
}

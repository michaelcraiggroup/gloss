import Foundation
import Testing
@testable import Gloss

/// Pins every Notification.Name rawValue string. These names are the
/// cross-platform wire between the shared services and both app shells —
/// a silent rename would disconnect observers with no compile error
/// anywhere, so the strings themselves are the contract.
@Suite("Gloss notification names")
struct GlossNotificationsTests {
    @Test func rawValuesArePinned() {
        let pinned: [(Notification.Name, String)] = [
            (.glossFindInPage, "glossFindInPage"),
            (.glossFindNext, "glossFindNext"),
            (.glossFindPrevious, "glossFindPrevious"),
            (.glossFileDrop, "glossFileDrop"),
            (.glossPrint, "glossPrint"),
            (.glossScrollToHeading, "glossScrollToHeading"),
            (.glossDocumentLoaded, "glossDocumentLoaded"),
            (.glossNavigateWikiLink, "glossNavigateWikiLink"),
            (.glossShowPaywall, "glossShowPaywall"),
            (.glossGuideReady, "glossGuideReady"),
            (.glossGuideStepComplete, "glossGuideStepComplete"),
            (.glossGuideStopped, "glossGuideStopped"),
            (.glossGuideDispatchWeb, "glossGuideDispatchWeb"),
            (.glossGuideStopWeb, "glossGuideStopWeb"),
            (.glossIndexUpdated, "glossIndexUpdated"),
            (.glossShowGraph, "glossShowGraph"),
            (.glossSaveFilled, "glossSaveFilled"),
            (.glossTemplateFilled, "glossTemplateFilled"),
            (.glossWebViewDidStartLoad, "glossWebViewDidStartLoad"),
            (.glossWebViewDidFinishLoad, "glossWebViewDidFinishLoad"),
            (.glossOpenPath, "glossOpenPath"),
            (.glossZoomChanged, "glossZoomChanged"),
            (.glossVaultFilesChanged, "glossVaultFilesChanged"),
            (.glossEditorDirtyChanged, "glossEditorDirtyChanged"),
            (.glossEditorSaved, "glossEditorSaved"),
            (.glossToggleEditMode, "glossToggleEditMode"),
            (.glossSetUpiPhone, "glossSetUpiPhone"),
        ]
        for (name, raw) in pinned {
            #expect(name.rawValue == raw)
        }
        #expect(pinned.count == 27)
    }
}

import Foundation

/// Every `Notification.Name` Gloss posts or observes, in one platform-neutral
/// file. These names are the cross-platform wire between the shared services
/// (LinkIndex, StoreManager, FileTreeModel, …) and each app shell (macOS
/// AppKit shell today, iOS shell next) — they must not live in platform view
/// files, or the other platform can't compile the services that post them.
/// The rawValue strings are pinned by GlossNotificationsTests.
extension Notification.Name {
    static let glossFindInPage = Notification.Name("glossFindInPage")
    static let glossFindNext = Notification.Name("glossFindNext")
    static let glossFindPrevious = Notification.Name("glossFindPrevious")
    static let glossFileDrop = Notification.Name("glossFileDrop")
    static let glossPrint = Notification.Name("glossPrint")
    static let glossScrollToHeading = Notification.Name("glossScrollToHeading")
    static let glossDocumentLoaded = Notification.Name("glossDocumentLoaded")
    static let glossNavigateWikiLink = Notification.Name("glossNavigateWikiLink")
    static let glossShowPaywall = Notification.Name("glossShowPaywall")
    static let glossGuideReady = Notification.Name("glossGuideReady")
    static let glossGuideStepComplete = Notification.Name("glossGuideStepComplete")
    static let glossGuideStopped = Notification.Name("glossGuideStopped")
    static let glossGuideDispatchWeb = Notification.Name("glossGuideDispatchWeb")
    static let glossGuideStopWeb = Notification.Name("glossGuideStopWeb")
    static let glossIndexUpdated = Notification.Name("glossIndexUpdated")
    static let glossShowGraph = Notification.Name("glossShowGraph")
    static let glossSaveFilled = Notification.Name("glossSaveFilled")
    static let glossTemplateFilled = Notification.Name("glossTemplateFilled")
    static let glossWebViewDidStartLoad = Notification.Name("glossWebViewDidStartLoad")
    static let glossWebViewDidFinishLoad = Notification.Name("glossWebViewDidFinishLoad")
    static let glossOpenPath = Notification.Name("glossOpenPath")
    /// Posted (object: Double zoom level) when the user changes read-mode page zoom.
    static let glossZoomChanged = Notification.Name("glossZoomChanged")
    /// Posted (object: [String] of changed paths) when the folder watcher
    /// detects on-disk changes anywhere under the open vault root.
    static let glossVaultFilesChanged = Notification.Name("glossVaultFilesChanged")
    static let glossEditorDirtyChanged = Notification.Name("glossEditorDirtyChanged")
    static let glossEditorSaved = Notification.Name("glossEditorSaved")
    static let glossToggleEditMode = Notification.Name("glossToggleEditMode")
    /// Opens the Set Up iPhone / Move Vault to iCloud sheet (macOS).
    static let glossSetUpiPhone = Notification.Name("glossSetUpiPhone")
    /// Posted by the vault watchers when `.gloss/favorites.json` changed on
    /// disk — the one `.gloss` path allowed out of the pipeline, so favorites
    /// synced from another device reload without echo loops.
    static let glossFavoritesFileChanged = Notification.Name("glossFavoritesFileChanged")
}

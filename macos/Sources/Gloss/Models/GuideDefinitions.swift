extension WalkthroughGuide {

    /// "What's New" guide for the Tags UI feature (Phase 8.5).
    static let whatsNewTags = WalkthroughGuide(
        id: "whats-new-tags-v1",
        name: "What's New: Tags",
        version: 1,
        steps: [
            .web(WebStep(
                id: "welcome",
                type: "content",
                target: nil,
                content: "# Tags are here!\n\nGloss now reads tags from your frontmatter and makes them browsable.",
                placement: "center"
            )),
            .native(NativeStep(
                id: "sidebar-tags",
                target: .sidebarTagsSection,
                content: "**Tags browser** — all tags in your vault, with file counts. Click any tag to filter.",
                placement: "trailing"
            )),
            .native(NativeStep(
                id: "inspector-tags",
                target: .inspectorTags,
                content: "**Inspector tags** — the current document's tags as clickable pills.",
                placement: "leading"
            )),
        ],
        documentResource: "whats-new-tags"
    )

    /// Onboarding guide for first-time users.
    static let gettingStarted = WalkthroughGuide(
        id: "getting-started-v1",
        name: "Getting Started with Gloss",
        version: 1,
        steps: [
            .web(WebStep(
                id: "welcome",
                type: "content",
                target: nil,
                content: "# Welcome to Gloss\n\nA distraction-free markdown reader. Let's take a quick tour.",
                placement: "center"
            )),
            .web(WebStep(
                id: "headings",
                type: "spotlight",
                target: "h1[id], h2[id]",
                content: "**Heading anchors** — hover any heading to see a link icon. Click to copy the anchor.",
                placement: "bottom"
            )),
            .web(WebStep(
                id: "code-blocks",
                type: "spotlight",
                target: "pre",
                content: "**Code blocks** — hover to reveal a copy button. Syntax highlighting included.",
                placement: "top"
            )),
            .native(NativeStep(
                id: "edit-mode",
                target: .toolbarEditMode,
                content: "**Edit mode** — switch to a live-preview editor (\u{21E7}\u{2318}E). Auto-saves when you switch back.",
                placement: "bottom"
            )),
            .native(NativeStep(
                id: "inspector",
                target: .toolbarInspectorToggle,
                content: "**Inspector** — table of contents, frontmatter, tags, and backlinks (\u{2325}\u{2318}I).",
                placement: "bottom"
            )),
            .native(NativeStep(
                id: "favorite",
                target: .toolbarFavorite,
                content: "**Favorites** — star documents for quick access (\u{2318}D).",
                placement: "bottom"
            )),
            .web(WebStep(
                id: "keyboard",
                type: "content",
                target: nil,
                content: "# Keyboard Navigation\n\n- **j/k** — scroll down/up\n- **gg** — top of page\n- **G** — bottom\n- **\u{2318}F** — find in page\n\nHappy reading!",
                placement: "center"
            )),
        ],
        documentResource: "getting-started"
    )
}

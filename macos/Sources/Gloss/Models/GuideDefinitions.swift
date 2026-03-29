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

    /// Comprehensive onboarding guide for new users.
    static let gettingStarted = WalkthroughGuide(
        id: "getting-started-v2",
        name: "Getting Started with Gloss",
        version: 2,
        steps: [
            // 1. Welcome
            .web(WebStep(
                id: "welcome",
                type: "content",
                target: nil,
                content: "# Welcome to Gloss\n\nA distraction-free markdown reader for macOS. Let\u{2019}s walk through everything you can do.",
                placement: "center"
            )),

            // 2. Beautiful rendering — spotlight a heading
            .web(WebStep(
                id: "headings",
                type: "spotlight",
                target: "h2[id]",
                content: "**Heading anchors** \u{2014} hover any heading to see a link icon. Click it to copy a deep link to that section.",
                placement: "bottom"
            )),

            // 3. Code blocks — spotlight a code block
            .web(WebStep(
                id: "code-blocks",
                type: "spotlight",
                target: "pre",
                content: "**Syntax highlighting** \u{2014} code blocks are highlighted automatically. Hover to reveal a one-click copy button.",
                placement: "top"
            )),

            // 4. Diagrams & math — spotlight the rendered mermaid diagram
            .web(WebStep(
                id: "diagrams-math",
                type: "spotlight",
                target: "pre.mermaid",
                content: "**Diagrams & Math** \u{2014} Mermaid diagrams and LaTeX math (KaTeX) render automatically from standard fenced blocks. No plugins needed.",
                placement: "bottom"
            )),

            // 5. Edit mode — native spotlight
            .native(NativeStep(
                id: "edit-mode",
                target: .toolbarEditMode,
                content: "**Edit mode** \u{2014} toggle a live-preview editor (\u{21E7}\u{2318}E). Markdown syntax hides on unfocused lines. Auto-saves when you switch back to reading mode.",
                placement: "bottom"
            )),

            // 6. Inspector — native spotlight
            .native(NativeStep(
                id: "inspector",
                target: .toolbarInspectorToggle,
                content: "**Inspector** \u{2014} open the sidebar (\u{2325}\u{2318}I) to see the table of contents, YAML frontmatter, tags, and backlinks for the current document.",
                placement: "bottom"
            )),

            // 7. Favorites — native spotlight
            .native(NativeStep(
                id: "favorite",
                target: .toolbarFavorite,
                content: "**Favorites** \u{2014} star any document (\u{2318}D) for quick access from the sidebar. Your favorites are always just one click away.",
                placement: "bottom"
            )),

            // 8. Folder sidebar & search
            .web(WebStep(
                id: "folder-sidebar",
                type: "content",
                target: nil,
                content: "## Folder Sidebar\n\nOpen a folder (\u{21E7}\u{2318}O) to browse all your markdown files in a tree view.\n\n- **Full-text search** across every file in your vault\n- **Recents** \u{2014} quickly revisit recent documents\n- **Favorites** \u{2014} your starred files, always at the top",
                placement: "center"
            )),

            // 9. Wiki-links & backlinks
            .web(WebStep(
                id: "wiki-links",
                type: "content",
                target: nil,
                content: "## Wiki-Links & Backlinks\n\nLink between documents with `[[wiki-links]]`. Gloss resolves them automatically within your folder.\n\nTyped links like `[[note::related]]` categorize relationships. The **Inspector** shows backlinks grouped by type.",
                placement: "center"
            )),

            // 10. Tags
            .web(WebStep(
                id: "tags",
                type: "content",
                target: nil,
                content: "## Tags\n\nAdd tags to your YAML frontmatter:\n\n```yaml\n---\ntags: [project, idea, draft]\n---\n```\n\nBrowse all tags in the sidebar, filter by tag, and see a document\u{2019}s tags as clickable pills in the Inspector.",
                placement: "center"
            )),

            // 11. Keyboard navigation
            .web(WebStep(
                id: "keyboard",
                type: "content",
                target: nil,
                content: "## Keyboard Navigation\n\nVim-style keys work in reading mode:\n\n- **j / k** \u{2014} scroll down / up\n- **gg** \u{2014} jump to top\n- **G** \u{2014} jump to bottom\n- **\u{2318}F** \u{2014} find in page\n- **\u{2318}G** \u{2014} find next match",
                placement: "center"
            )),

            // 12. Export & productivity
            .web(WebStep(
                id: "export",
                type: "content",
                target: nil,
                content: "## Export & More\n\n- **\u{2318}P** \u{2014} Print\n- **\u{2318}E** \u{2014} Export as PDF\n- **\u{2318}\\\\** \u{2014} Zen mode (hide sidebar & chrome)\n- **Quick Look** \u{2014} press Space on any .md file in Finder for an instant preview",
                placement: "center"
            )),

            // 13. Done
            .web(WebStep(
                id: "done",
                type: "content",
                target: nil,
                content: "# You\u{2019}re all set!\n\nRevisit this tour anytime from **Help \u{2192} Getting Started Tour**.\n\nHappy reading!",
                placement: "center"
            )),
        ],
        documentResource: "getting-started"
    )
}

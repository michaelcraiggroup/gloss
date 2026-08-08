# Gloss — App Store Metadata

> Copy revision 2026-08-08 — behavior-first hierarchy, feature map verified against
> [`docs/APP_STORE_READINESS.md`](../docs/APP_STORE_READINESS.md) Part 1 (v1.23.0).
> Resolves blocker **B8** of [#74](https://github.com/michaelcraiggroup/gloss/issues/74).
> See "Copy decisions" at the bottom before editing claims.

## App Name
Gloss - Markdown Reader

## Subtitle (30 chars max)
Opens to read. Edits on demand

## Description

Gloss opens to read.

Point it at a markdown file — or a whole vault of them — and it renders beautifully: calm typography, syntax-highlighted code, Mermaid diagrams, KaTeX math. No blinking cursor, no accidental edits. Your notes are a body of work, and Gloss treats them that way.

Think Preview.app, but for markdown. And when you do want to change something, editing is one keystroke away: ⇧⌘E switches to a live-preview editor that renders as you type. Reading is the default. Editing is on demand.

READ — FREE
- Beautiful rendering for any markdown file
- Syntax highlighting for dozens of languages
- Mermaid diagrams and KaTeX math
- Dark and light themes that follow your system
- Document zoom (⌘= / ⌘−) and a distraction-free zen mode (⌃⌘Z)
- Quick Look — press spacebar on any .md file in Finder
- Live reload — changes from any editor appear instantly
- Vim-style keys (j/k/gg/G), copy-code buttons, heading anchor links
- Find in page (⌘F), print, and PDF export
- Open in your editor of choice (Cursor, VS Code, Zed, Sublime, and more)

WRITE — FREE
- Live-preview editor (⇧⌘E) — markdown renders as you type
- Create, rename, and delete files; auto-save when you switch back to reading
- Fillable templates — complete checklists and forms in read mode, then save a filled copy

GLOSS PRO — $9.99, ONE-TIME
Turn any folder into a vault:
- Folder sidebar with your whole file tree
- Full-text search across every note
- Wiki-links — [[links]] between notes, with typed relations like [[idea::supports]]
- Backlinks and unlinked mentions — see every note that points here
- Table of contents, tags, and frontmatter properties you can edit in place
- Transclusion — embed one note inside another with ![[note#heading]]
- Queries — live lists of notes by tag, link, or property, right inside a document
- Daily notes (⌘T) and quick capture from the menu bar — jot a thought without switching apps
- Vault dashboard — the shape of your notes at a glance
- Favorites and recents, scoped to each vault
- Reading font size control

NO SUBSCRIPTION. NO ADS. NO TRACKING. EVER.

No accounts, no analytics, no telemetry. Your files never leave your Mac, and your reading is nobody's data. Buy once, keep it forever.

Gloss is made by Off-Leash — the privacy-first software studio from Michael Craig Group, LLC. Your work belongs to you.

## Keywords (100 chars max)
markdown,reader,notes,vault,wiki,backlinks,editor,viewer,docs,quicklook,privacy,knowledge,mermaid

## Category
Developer Tools (primary), Productivity (secondary)

## What's New (v1.23)
Gloss arrives on the Mac App Store as a reader that grew into a knowledgebase, refined across twenty-three releases: a live-preview editor (⇧⌘E), wiki-links and backlinks, full-text search, transclusion, live queries, daily notes, quick capture, and a Quick Look extension for Finder. Version 1.23 debuts a vault-first sidebar. Gloss Pro ($9.99 one-time, Family Sharing) unlocks vault features: folder browsing, search, wiki-links, and more.

## Privacy URL
https://michaelcraig.group/privacy

## Support URL
https://michaelcraig.group/support

## Marketing URL
https://michaelcraig.group/products/gloss

## Screenshots (5 planned + 2 optional, 1280x800 or 2560x1600)

Canonical five — 📸 markers live in [`docs/DEMO_WALKTHROUGH.md`](../docs/DEMO_WALKTHROUGH.md); capture during the Phase 5 verification pass:

1. **Hero**: vault sidebar + `Syntax Showcase.md` or a real README, dark (Night Owl) theme
2. **Inspector**: TOC open on a long document — heading hierarchy, frontmatter, tags
3. **Wiki-links**: a note with visible [[wiki-links]], cursor hovering one
4. **Quick Look**: Finder window, spacebar preview rendering through Gloss
5. **Light theme**: same document in Reading Desk light — clean typography, amber accents

Optional additions (the store allows up to 10; add 📸 markers to the walkthrough if used):

6. **Editor**: live preview mid-edit, markdown rendering as you type — the listing's second act
7. **Capture**: today's daily note (⌘T) with the quick-capture panel open

Rule: nothing in frame contradicts the listing — no graph, no personal filenames, no placeholder text.

## Promotional Text (170 chars max)
Gloss opens to read — notes, docs, vaults, beautifully rendered — and edits the moment you ask. Wiki-links, daily notes, quick capture. Pay once. No tracking, ever.

## App Store Product ID
group.michaelcraig.gloss.full — Non-Consumable, $9.99, Family Sharing enabled
(Legacy ".full" ID kept — existing purchases own it. Display name in App Store Connect: "Gloss Pro".)

## Copy decisions (2026-08-08, B8 of #74)

- **Hierarchy**: master line is the behavior ("opens to read"); "Preview.app, but for markdown" is demoted to explainer. Subtitle now matches the master line.
- **B4 — language claim softened** to "dozens of languages" pending the Ada litmus. If the full highlight.js build ships, restore "180+ languages" in the description; nothing else depends on it.
- **B10 — privacy copy is CDN-safe**: "your files never leave your Mac" is true with or without bundled renderers ("never phones home" was not, and is gone). If hljs/Mermaid/KaTeX get bundled locally, you may strengthen to "works entirely offline".
- **Gating honesty**: quick capture, daily notes, transclusion, queries, and the dashboard carry no individual store gate but require an open vault (the Pro unlock), so they are listed under Pro — the safe direction for review. Fillable templates have no gate and work on any open file, so they are listed free.
- **Deliberately unadvertised**: the CLI installer (goes in App Review notes instead — B13) and guided walkthroughs (discoverable in the Help menu).

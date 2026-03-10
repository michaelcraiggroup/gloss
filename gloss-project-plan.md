# Gloss

> **Gloss through your markdown without touching it.**

A distraction-free markdown reader — as a VS Code extension and a standalone macOS app. Read your docs, don't edit them.

---

## Category

**ORGANIZE** — Tools that structure workflow

**Gradient:** `teal-900 → cyan-900 → sky-950`

---

## Current State

**VS Code Extension (v0.2.2)** — Published on marketplace. Custom webview reader with syntax highlighting, mermaid diagrams, KaTeX math, find-in-page, print, copy buttons, YAML frontmatter stripping, and image rendering. Zero telemetry.

**macOS App (v0.11.0)** — Development builds working via SPM and xcodegen. NavigationSplitView with file browser sidebar, inspector sidebar (TOC + frontmatter), full-text content search, favorites, Quick Look extension, find-in-page, mermaid diagrams, KaTeX math, heading anchor links, wiki-link navigation, PDF export, StoreKit 2 paywall. 122 tests passing. Pending: feature gate enforcement, signing, notarization, App Store submission.

---

## The Problem

**In VS Code:** The markdown workflow has friction for read-only use cases:

1. **Double-click disruption** — Double-clicking in preview switches back to editor view
2. **No direct-to-preview** — Markdown files always open in code view first
3. **Tab clutter** — Preview opens as a separate tab alongside the source
4. **No dedicated reading mode** — No way to just *read* without risking edits

**Outside VS Code:** There's no good way to browse markdown files without an editor:

1. **Preview apps don't exist** — macOS Preview.app doesn't render markdown, Quick Look support is limited
2. **Every tool wants to edit** — Obsidian, Typora, iA Writer — they're all editors
3. **Knowledge bases are fragmented** — Docs live in repos, vaults, random folders. No unified reader

**Target users:** Developers reading documentation, note-takers reviewing their markdown files, anyone with markdown scattered across their filesystem.

---

## A Different Approach

Reading and writing are different mental modes. When I'm reading documentation, I don't want to risk changing it. When I'm writing, I don't want preview chrome in my way.

Gloss treats these as separate concerns: open to read, explicitly switch to edit. The default is *preservation*, not modification.

---

## Gloss for macOS (Standalone App)

A native markdown browser that treats `.md` files as documents to *read*, not edit.

### Core Concept

Gloss for macOS is a **read-only markdown browser** — think Preview.app, but for markdown. Open files, browse folders, read documentation. When you need to edit, Gloss hands off to your preferred editor.

### Implemented Features

| Feature | Status |
|---------|--------|
| **File browser sidebar** | ✅ NavigationSplitView with recursive tree |
| **Rendered preview** | ✅ swift-markdown + WKWebView + GlossKit |
| **Quick Look extension** | ✅ Embedded QL generator for `.md` files |
| **"Open in Editor" action** | ✅ Cmd+E with configurable editor |
| **Editor picker** | ✅ Cursor, Windsurf, VS Code, VSCodium, System Default |
| **Recents / Favorites** | ✅ SwiftData + Cmd+D toggle |
| **Full-text search** | ✅ Async debounced with search scopes |
| **Find-in-page** | ✅ Cmd+F with match navigation |
| **Print** | ✅ Cmd+P with native NSPrintOperation |
| **Font size control** | ✅ CSS variable + stepper (12-24px) |
| **Keyboard navigation** | ✅ Vim-style j/k, gg/G, Space/Shift+Space |
| **Copy buttons** | ✅ Hover-to-reveal on code blocks |
| **Mermaid diagrams** | ✅ CDN rendering with theme detection |
| **KaTeX math** | ✅ Inline and display math |
| **Live reload** | ✅ DispatchSource file watcher |
| **Dark mode** | ✅ System-aware + explicit toggle |

### Future Features

| Feature | Description |
|---------|-------------|
| **Multiple root folders** | Add several directories as "libraries" |
| **Tags / Frontmatter display** | Show YAML frontmatter metadata |
| **Backlinks** | Wiki-style "which files link here" |
| **Custom CSS themes** | User-configurable typography and colors |
| **Export to PDF** | Print-ready output |
| **Spotlight integration** | Index markdown content for system search |

---

## Privacy

**Your reading habits are yours.** Both the VS Code extension and macOS app run entirely locally. No analytics, no telemetry.

**VS Code Extension:**
- All configuration stored locally in VS Code settings
- CDN resources loaded for rendering (highlight.js, mermaid.js, KaTeX) — no data sent
- No usage tracking or behavioral analytics
- Open source — verify it yourself

**macOS App:**
- Recents/favorites stored locally in SwiftData (on-device only)
- No iCloud sync (your reading history stays on your Mac)
- No analytics SDK, no Firebase, no Crashlytics
- File access uses standard macOS sandboxing and permissions
- Quick Look extension processes files locally, no network calls

This isn't a privacy policy, it's the architecture. There's no server to send data to.

---

## Monetization

**VS Code Extension:** Free / Open Source (MIT)

The extension is a trust-builder and lead generator for the macOS app. A free, well-crafted extension demonstrates the "sharp tools that don't spy on you" principle and funnels developers to the native app.

**macOS App:** Free download with $4.99 in-app purchase unlock (StoreKit 2)

### Free Tier (Taste the Quality)

| Feature | Included |
|---------|----------|
| Open individual files (File > Open, drag-and-drop) | ✅ |
| Full rendered preview (syntax highlighting, mermaid, KaTeX) | ✅ |
| Open in Editor (Cmd+E) | ✅ |
| Dark/light theme | ✅ |
| Quick Look extension | ✅ |
| Live reload | ✅ |
| Keyboard navigation | ✅ |
| Copy buttons on code blocks | ✅ |

### Paid: Gloss Full ($4.99 one-time)

| Feature | Description |
|---------|-------------|
| **Folder sidebar** | Browse any directory as a library |
| **Full-text search** | Search across all files in a folder |
| **Favorites** | Star documents, Cmd+D toggle |
| **Recents** | Recently opened files list |
| **Find-in-page** | Cmd+F search within rendered view |
| **Print** | Cmd+P with optimized layout |
| **Font size control** | Customize reading experience (12-24px) |

### Pricing Rationale

- **$4.99 is the impulse-buy threshold.** Under $5 removes deliberation for the App Store audience. Developer tools are price-sensitive but willing to pay for things that work.
- **The paywall sits at the commitment moment.** Free users open individual files — paid users use Gloss as their markdown browser. The upgrade triggers when someone wants folder browsing, not single-file preview.
- **Quick Look stays free as the viral hook.** Every spacebar press on a `.md` file in Finder is a free ad for Gloss. Gating it would kill the best organic growth mechanism.
- **No subscription, ever.** There's no ongoing service cost. A subscription would feel extractive for a 100% local app. One-time purchase is a brand promise.
- **No ads, ever.** MCG principle. Non-negotiable.

### Revenue Context

Gloss is a **credibility builder** and **funnel opener**, not a primary revenue driver. Its value to the MCG portfolio exceeds direct revenue — every Gloss user is a potential Merrily/Rumpus/Jotto customer who already trusts MCG's taste and privacy commitment.

**Why charge for the macOS app:**
- Native app development has higher maintenance cost
- App Store distribution has overhead (review, certificates, fees)
- One-time purchase aligns with "no subscription, you own it" values
- Follows the Zephster model (paid iOS app, privacy as differentiator)

**Why keep VS Code extension free:**
- Lower maintenance once stable
- Builds credibility in developer community
- Drives awareness of the macOS app and broader portfolio

---

## Development Milestones

### macOS App

#### Phase 1: Foundation ✅
- [x] Swift Package with SwiftUI, markdown rendering via swift-markdown + WKWebView
- [x] "Open in Editor" with Cursor/VS Code URL schemes, settings view
- [x] 13 tests passing

#### Phase 2: File Browser ✅
- [x] FileTreeNode with lazy loading, FileTreeModel (@Observable), RecentDocument SwiftData model
- [x] NavigationSplitView with sidebar + detail, FileWatcher for live reload
- [x] 34 tests passing

#### Phase 3: Quick Look & Polish ✅
- [x] GlossKit shared library, font size control, copy buttons, keyboard nav, sidebar search
- [x] Quick Look extension scaffolding with document type declarations
- [x] 56 tests passing

#### Phase 4: Search & Favorites ✅
- [x] Full-text content search (async, debounced, TaskGroup), search scopes
- [x] Favorites system with Cmd+D toggle, toolbar star, context menus
- [x] 68 tests passing

#### Phase 4.5: Find-in-Page ✅
- [x] JS-based find bar (both platforms), TreeWalker text matching
- [x] Cmd+F/G/Shift+G navigation, match counter
- [x] 76 tests passing

#### Phase 4.6: Mermaid Diagrams ✅
- [x] Mermaid.js CDN rendering (v11.12.0), conditional loading, theme detection
- [x] 85 tests passing

#### Phase 4.7: KaTeX Math ✅
- [x] KaTeX 0.16.9 CDN, auto-render, conditional loading (both platforms)
- [x] 98 tests passing

#### Phase 5.5: Pre-Launch Features (Complete)
- [x] Heading IDs + anchor links (slug generation, `id` attrs, hover anchor CSS/JS)
- [x] Yams dependency + frontmatter extraction (`FrontmatterData` model, YAML parsing)
- [x] Heading extraction API (`HeadingInfo` model, AST walking)
- [x] Inspector sidebar (SwiftUI `.inspector()`, TOC with click-to-jump, frontmatter display)
- [x] Wiki-link rendering (`[[target]]` + `[[target|display]]` pre-processing, BFS resolution)
- [x] Wiki-link navigation (WKWebView link interception, file tree search)
- [x] PDF export (`WKWebView.createPDF()`, File > Export as PDF menu command)
- [x] External link handling (opens in default browser)
- [x] StoreKit 2 paywall (`StoreManager`, `PaywallView`, `PaidFeature` enum)
- [x] 122 tests passing

#### Phase 5: Release (In Progress)
- [x] Xcode project wrapper via xcodegen (`project.yml` → `Gloss.xcodeproj`)
- [x] App sandbox entitlements, Quick Look extension embeds in app bundle
- [x] Dual build: SPM + Xcode both work
- [x] In-app purchase gate (StoreKit 2) — free/paid tier split
- [x] Feature gate enforcement (wire paywall checks into views)
- [x] StoreKit test configuration (GlossStore.storekit for local paywall testing)
- [x] App Store metadata draft (AppStoreMetadata.md — name, description, keywords)
- [x] Version set to 1.0.0 (MARKETING_VERSION + CURRENT_PROJECT_VERSION)
- [x] Xcode build verified with signing (Apple Development certificate)
- [ ] App Store Connect product setup (group.michaelcraig.gloss.full — $4.99 non-consumable)
- [ ] Developer ID signing + notarization (for direct distribution)
- [ ] App Store screenshots (5 required)
- [ ] "Coming soon" link in VS Code extension
- [ ] TestFlight beta
- [ ] App Store submission

#### Phase 6: Launch & Marketing
- [ ] Landing page on michaelcraig.group/products/gloss
- [ ] Blog post: "Why I built a markdown reader that doesn't edit"
- [ ] Product Hunt launch
- [ ] Show HN post
- [ ] Social media campaign (Twitter/X, Mastodon, LinkedIn)
- [ ] Submit to macOS utility directories
- [ ] Pricing iteration based on conversion data (Month 1-3)

---

## Future Work

- **md+ (Extended Markdown)** — Vision for executable markdown with live code blocks, data queries, and interactive widgets. See [MD+ Specification](docs/MD_PLUS_SPEC.md).
- **iOS companion** — Natural extension, deferred until macOS app proves demand.
- **v1.1 "The Vault Update"** — Multiple root folders, backlinks panel, tag extraction + filtering
- **v1.2 "The Polish Update"** — Custom CSS themes, Spotlight integration, reading position memory, tabs
- **v1.3 "The Power Update"** — md+ block rendering, URL scheme / CLI, link graph visualization

---

## Cross-Portfolio Links

Gloss fits within the Michael Craig Group portfolio as a two-product offering demonstrating core values:

- **Privacy by architecture** — No data collection because there's no server
- **Local-first** — Everything happens on your machine
- **Sharp tools** — Does one thing well, doesn't try to be a full note-taking system
- **No subscription** — VS Code extension is free, macOS app is one-time purchase

**Follows the Zephster model:** Like Zephster (paid iOS app, privacy as differentiator), Gloss for macOS is a native app with a one-time purchase that competes on "we don't spy on you" versus free alternatives.

Related products:
- **Jotto** — Desktop daily notes with intelligent task forwarding
- **Mulholland** — Full filmmaking toolchain
- **Zephster** — Flight tracking that tracks flights, not users

---

## Resources

### VS Code Extension
- [VS Code Extension API](https://code.visualstudio.com/api)
- [Publishing Extensions](https://code.visualstudio.com/api/working-with-extensions/publishing-extension)

### macOS App
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [SwiftData](https://developer.apple.com/documentation/swiftdata)
- [Quick Look Programming Guide](https://developer.apple.com/documentation/quicklook)
- [swift-markdown](https://github.com/apple/swift-markdown)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

---

## License

MIT — Free to use, modify, and distribute.

---

*A [Michael Craig Group](https://michaelcraig.group) project — sharp tools that don't spy on you.*

# Gloss

> **Gloss through your markdown without touching it.**

A distraction-free markdown reader — as a VS Code extension and a standalone macOS app. Read your docs, don't edit them.

---

## Category

**ORGANIZE** — Tools that structure workflow

**Gradient:** `teal-900 → cyan-900 → sky-950`

---

## The Problem

**In VS Code:** The markdown workflow has friction for read-only use cases:

1. **Double-click disruption** — Double-clicking in preview (to select text, copy, etc.) switches back to editor view
2. **No direct-to-preview** — Markdown files always open in code view first; you must manually trigger preview
3. **Tab clutter** — Preview opens as a separate tab alongside the source, doubling your tab count
4. **No dedicated reading mode** — Zen Mode exists, but requires manual setup each time

**Outside VS Code:** There's no good way to browse markdown files without an editor:

1. **Preview apps don't exist** — macOS Preview.app doesn't render markdown, Quick Look support is limited
2. **Every tool wants to edit** — Obsidian, Typora, iA Writer — they're all editors. Sometimes I just want to *read*
3. **Web-based tools require conversion** — GitHub renders markdown, but you have to push it there first
4. **Knowledge bases are fragmented** — Docs live in repos, Obsidian vaults, random folders. No unified reader

I got tired of accidentally editing documentation I just wanted to read. Gloss is the tool I wished existed — both inside my editor and as a standalone browser for everything else.

**Target users:** Developers reading documentation, note-takers reviewing their markdown files, anyone with markdown scattered across their filesystem.

---

## A Different Approach

Reading and writing are different mental modes. When I'm reading documentation, I don't want to risk changing it. When I'm writing, I don't want preview chrome in my way.

Gloss treats these as separate concerns: open to read, explicitly switch to edit. The default is *preservation*, not modification.

---

## What You Get

### MVP (v0.1.0)

| Feature | Description |
|---------|-------------|
| **Auto-preview on open** | Configurable file patterns trigger preview-first behavior |
| **Close source tab** | Automatically close the editor tab, leaving only preview |
| **Disable double-click** | Prevents accidental switch to editor on text selection |
| **Edit command** | Command palette action: "Gloss: Edit This File" to return to source |
| **Status bar indicator** | Shows "📖 Reading" when in Gloss mode |

### Future (v0.2.0+)

| Feature | Description |
|---------|-------------|
| **Auto-Zen Mode** | Optionally enter Zen Mode when opening markdown |
| **Folder/workspace rules** | Different behavior for different directories |
| **Preview styling** | Custom CSS for reading-optimized typography |
| **Keyboard navigation** | Vim-style `j/k` scrolling in preview |
| **Reading progress** | Track position, remember where you left off |
| **Table of contents overlay** | Quick navigation via heading outline |

---

## Gloss for macOS (Standalone App)

A native markdown browser that treats `.md` files as documents to *read*, not edit.

### Core Concept

Gloss for macOS is a **read-only markdown browser** — think Preview.app, but for markdown. Open files, browse folders, read documentation. When you need to edit, Gloss hands off to your preferred editor.

### MVP Features

| Feature | Description |
|---------|-------------|
| **File browser sidebar** | Navigate folders, Obsidian vaults, repo docs |
| **Rendered preview** | Clean markdown rendering with syntax highlighting for code blocks |
| **Quick Look integration** | Register as Quick Look generator for `.md` files |
| **"Open in Editor" action** | `Cmd+E` opens current file in configured editor |
| **Editor picker** | Configure: Cursor, Windsurf, VS Code, or default (all VS Code forks initially) |
| **Recents / Favorites** | Quick access to frequently-read docs |
| **Search** | Full-text search across open folder |

### Future Features

| Feature | Description |
|---------|-------------|
| **Multiple root folders** | Add several directories as "libraries" |
| **Tags / Frontmatter display** | Show YAML frontmatter metadata |
| **Backlinks** | See which files link to the current file (wiki-style) |
| **Dark mode** | System-aware theming |
| **Custom CSS themes** | User-configurable typography and colors |
| **Export to PDF** | Print-ready output |
| **Spotlight integration** | Index markdown content for system search |

### Editor Integration

The "Open in Editor" feature uses URL schemes to launch the appropriate editor:

```swift
// Editor URL schemes (all VS Code forks)
enum Editor: String, CaseIterable {
    case cursor = "cursor://file/"
    case windsurf = "windsurf://file/"
    case vscode = "vscode://file/"
    case vscodium = "vscodium://file/"
    case system = "" // Uses NSWorkspace.open with default app
    
    func openFile(at path: String) {
        if self == .system {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } else {
            let url = URL(string: "\(rawValue)\(path)")!
            NSWorkspace.shared.open(url)
        }
    }
}
```

**Settings UI:**
- Dropdown: "Open files in: [Cursor ▾]"
- Options: Cursor, Windsurf, VS Code, VSCodium, System Default
- Keyboard shortcut: `Cmd+E` (configurable)

### Technical Architecture

**Stack:** SwiftUI + SwiftData (for recents/favorites) + swift-markdown or cmark for parsing

```
Gloss.app/
├── GlossApp.swift              # App entry, window management
├── Models/
│   ├── Document.swift          # Markdown document model
│   ├── Library.swift           # Folder/root management
│   └── Settings.swift          # User preferences (editor choice, theme)
├── Views/
│   ├── ContentView.swift       # Main split view
│   ├── SidebarView.swift       # File browser
│   ├── DocumentView.swift      # Rendered markdown
│   ├── SettingsView.swift      # Preferences window
│   └── Components/
│       ├── MarkdownRenderer.swift
│       └── FileTreeView.swift
├── Services/
│   ├── MarkdownParser.swift    # cmark/swift-markdown wrapper
│   ├── FileWatcher.swift       # FSEvents for live reload
│   ├── SearchService.swift     # Full-text search
│   └── EditorLauncher.swift    # URL scheme handling
├── QuickLook/
│   └── GlossQLGenerator/       # Quick Look extension target
└── Resources/
    └── default-theme.css       # Default markdown styling
```

### Quick Look Extension

Register Gloss as a Quick Look generator for `.md` files:

```swift
// GlossQLGenerator/PreviewProvider.swift
class PreviewProvider: QLPreviewProvider {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let markdown = try String(contentsOf: request.fileURL, encoding: .utf8)
        let html = MarkdownParser.toHTML(markdown, withCSS: embeddedCSS)
        return QLPreviewReply(dataOfContentType: .html, contentSize: .zero) { _ in
            html.data(using: .utf8)!
        }
    }
}
```

This gives rendered markdown preview in Finder's Quick Look (spacebar) system-wide.

---

## Privacy

**Your reading habits are yours.** Both the VS Code extension and macOS app run entirely locally. No analytics, no telemetry, no network requests. Gloss doesn't know or care what you read.

**VS Code Extension:**
- All configuration stored locally in VS Code settings
- No usage tracking or behavioral analytics
- No external dependencies that phone home
- Open source — verify it yourself

**macOS App:**
- Recents/favorites stored locally in SwiftData (on-device only)
- No iCloud sync (your reading history stays on your Mac)
- No analytics SDK, no Firebase, no Crashlytics
- File access uses standard macOS sandboxing and permissions
- Quick Look extension processes files locally, no network calls

This isn't a privacy policy, it's the architecture. There's no server to send data to.

**Data location:**
- Extension: VS Code's settings storage (`~/.vscode/` or equivalent)
- macOS app: `~/Library/Containers/group.michaelcraig.gloss/` (sandboxed)

---

## Monetization

**VS Code Extension:** Free / Open Source (MIT)

The extension is a trust-builder for the portfolio, not a revenue product. A free, well-crafted extension demonstrates the "sharp tools that don't spy on you" principle.

**macOS App:** Paid (one-time purchase, ~$9.99)

| Tier | Price | Features |
|------|-------|----------|
| **Free** | $0 | Single-file viewing, basic rendering, "Open in Editor" |
| **Full** | $9.99 | Folder browsing, search, favorites, Quick Look integration, custom themes |

**Why charge for the macOS app:**
- Native app development has higher maintenance cost
- App Store distribution has overhead (review, certificates, fees)
- One-time purchase aligns with "no subscription, you own it" values
- Follows the Zephster model (paid iOS app, privacy as differentiator)

**Why keep VS Code extension free:**
- Lower maintenance once stable
- Builds credibility in developer community
- Drives awareness of the macOS app and broader portfolio
- Extension marketplace has different economics (discovery vs. direct revenue)

**Potential future:** If significant traction, consider "Gloss Pro" features for the extension (advanced navigation, cross-workspace reading lists) as a one-time purchase. But keep the core free forever.

---

## Configuration

```jsonc
// settings.json
{
  // Enable/disable Gloss entirely
  "gloss.enabled": true,
  
  // File patterns to open in reading mode
  "gloss.patterns": ["**/*.md", "**/*.markdown"],
  
  // Patterns to exclude (always open in editor)
  "gloss.exclude": ["**/CHANGELOG.md", "**/README.md"],
  
  // Auto-enter Zen Mode when opening in reading mode
  "gloss.zenMode": false,
  
  // Show status bar indicator
  "gloss.showStatusBar": true,
  
  // Keyboard shortcut hint in status bar
  "gloss.statusBarHint": true
}
```

---

## Commands

| Command | Default Keybinding | Description |
|---------|-------------------|-------------|
| `gloss.editFile` | `Ctrl+Shift+E` | Switch from preview to editor |
| `gloss.toggleEnabled` | — | Enable/disable Gloss globally |
| `gloss.openInReadingMode` | — | Force open current file in reading mode |
| `gloss.openInEditMode` | — | Force open current file in edit mode |

---

## Technical Approach

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Extension Host                        │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  Activation │  │   Config    │  │  Commands   │     │
│  │   Handler   │  │   Manager   │  │   Handler   │     │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │
│         │                │                │            │
│         ▼                ▼                ▼            │
│  ┌─────────────────────────────────────────────────┐   │
│  │            Document Open Listener               │   │
│  │   onDidOpenTextDocument → check patterns        │   │
│  │   → execute preview command                     │   │
│  │   → close editor tab                            │   │
│  └─────────────────────────────────────────────────┘   │
│                        │                               │
│                        ▼                               │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Status Bar Manager                 │   │
│  │   Track reading/editing state                   │   │
│  │   Provide quick toggle                          │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Key Implementation Details

1. **Document open interception**
   ```typescript
   vscode.workspace.onDidOpenTextDocument(async (doc) => {
     if (shouldOpenInReadingMode(doc)) {
       await vscode.commands.executeCommand('markdown.showPreview');
       await closeEditorTab(doc);
     }
   });
   ```

2. **Pattern matching** — Use `minimatch` or VS Code's built-in glob matching

3. **Tab management** — Close the source tab after preview opens:
   ```typescript
   const edit = vscode.window.activeTextEditor;
   if (edit?.document === doc) {
     await vscode.commands.executeCommand('workbench.action.closeActiveEditor');
   }
   ```

4. **Settings sync** — On activation, ensure `markdown.preview.doubleClickToSwitchToEditor` is `false`

### Edge Cases

- **Already open files** — Don't re-trigger on focus changes
- **Workspace trust** — Respect restricted mode
- **Remote development** — Test with SSH, WSL, containers
- **Other extensions** — Avoid conflicts with Markdown Preview Enhanced, etc.

---

## Project Structure

### VS Code Extension

```
gloss-vscode/
├── .vscode/
│   ├── launch.json          # Debug configuration
│   └── tasks.json           # Build tasks
├── src/
│   ├── extension.ts         # Entry point, activation
│   ├── config.ts            # Configuration management
│   ├── documentHandler.ts   # Open/close logic
│   ├── commands.ts          # Command implementations
│   ├── statusBar.ts         # Status bar management
│   └── utils/
│       ├── patterns.ts      # Glob matching utilities
│       └── logging.ts       # Debug logging
├── test/
│   ├── suite/
│   │   ├── extension.test.ts
│   │   └── patterns.test.ts
│   └── runTest.ts
├── .eslintrc.json
├── .prettierrc
├── .gitignore
├── CHANGELOG.md
├── LICENSE                   # MIT
├── package.json
├── README.md
├── tsconfig.json
└── vsc-extension-quickstart.md
```

### macOS App

```
Gloss/
├── Gloss.xcodeproj
├── Gloss/
│   ├── GlossApp.swift              # App entry point
│   ├── ContentView.swift           # Main window layout
│   ├── Models/
│   │   ├── Document.swift          # Markdown document model
│   │   ├── Library.swift           # Folder/library management
│   │   ├── RecentDocument.swift    # SwiftData model for recents
│   │   └── AppSettings.swift       # User preferences
│   ├── Views/
│   │   ├── SidebarView.swift       # File browser sidebar
│   │   ├── DocumentView.swift      # Rendered markdown view
│   │   ├── SettingsView.swift      # Preferences window
│   │   └── Components/
│   │       ├── FileTreeRow.swift
│   │       ├── MarkdownView.swift
│   │       └── SearchBar.swift
│   ├── Services/
│   │   ├── MarkdownParser.swift    # cmark/swift-markdown wrapper
│   │   ├── FileWatcher.swift       # FSEvents for live reload
│   │   ├── SearchService.swift     # Full-text search
│   │   └── EditorLauncher.swift    # URL scheme handling
│   ├── Resources/
│   │   ├── Assets.xcassets         # App icons
│   │   ├── default-theme.css       # Default markdown CSS
│   │   └── Localizable.strings
│   └── Info.plist
├── GlossQLExtension/               # Quick Look extension target
│   ├── PreviewProvider.swift
│   ├── Info.plist
│   └── GlossQLExtension.entitlements
├── GlossTests/
│   ├── MarkdownParserTests.swift
│   ├── EditorLauncherTests.swift
│   └── SearchServiceTests.swift
└── README.md
```

---

## package.json Essentials

```jsonc
{
  "name": "gloss",
  "displayName": "Gloss",
  "description": "Distraction-free markdown reading for VS Code",
  "version": "0.1.0",
  "publisher": "michaelcraig",
  "repository": {
    "type": "git",
    "url": "https://github.com/michaelcraig/gloss"
  },
  "engines": {
    "vscode": "^1.85.0"
  },
  "categories": ["Other", "Visualization"],
  "keywords": ["markdown", "preview", "reader", "zen", "documentation", "reading"],
  "activationEvents": [
    "onLanguage:markdown"
  ],
  "main": "./out/extension.js",
  "contributes": {
    "commands": [
      {
        "command": "gloss.editFile",
        "title": "Edit This File",
        "category": "Gloss"
      },
      {
        "command": "gloss.toggleEnabled",
        "title": "Toggle Reading Mode",
        "category": "Gloss"
      }
    ],
    "configuration": {
      "title": "Gloss",
      "properties": {
        "gloss.enabled": {
          "type": "boolean",
          "default": true,
          "description": "Enable Gloss reading mode for markdown files"
        },
        "gloss.patterns": {
          "type": "array",
          "default": ["**/*.md"],
          "description": "Glob patterns for files to open in reading mode"
        },
        "gloss.exclude": {
          "type": "array",
          "default": [],
          "description": "Glob patterns to exclude from reading mode"
        },
        "gloss.zenMode": {
          "type": "boolean",
          "default": false,
          "description": "Automatically enter Zen Mode when opening markdown"
        }
      }
    },
    "keybindings": [
      {
        "command": "gloss.editFile",
        "key": "ctrl+shift+e",
        "mac": "cmd+shift+e",
        "when": "activeEditor == 'workbench.editor.markdown.previewEditor'"
      }
    ]
  }
}
```

---

## Development Milestones

### VS Code Extension

#### Phase 1: Foundation (Week 1)
- [ ] Scaffold extension with Yeoman generator
- [ ] Implement basic document open listener
- [ ] Add configuration schema
- [ ] Test manual preview triggering

#### Phase 2: Core Features (Week 2)
- [ ] Pattern matching with include/exclude
- [ ] Tab closing after preview open
- [ ] Edit command to return to source
- [ ] Status bar indicator

#### Phase 3: Polish (Week 3)
- [ ] Edge case handling (already open, remote, etc.)
- [ ] Integration tests
- [ ] README with GIFs/screenshots
- [ ] Marketplace assets (icon, banner)

#### Phase 4: Release (Week 4)
- [ ] Beta testing in Cursor/Windsurf
- [ ] Marketplace submission
- [ ] Announce on michaelcraig.group

### macOS App

#### Phase 1: Foundation ✅
- [x] Create Swift Package with SwiftUI
- [x] Implement markdown rendering via swift-markdown + WKWebView
- [x] Single-file open and display
- [x] "Open in Editor" with Cursor/VS Code URL schemes
- [x] Settings view for editor selection
- [x] 13 tests passing

#### Phase 2: File Browser ✅
- [x] DocumentType model ported from extension (14 cases, icon detection)
- [x] FileTreeNode with lazy one-level loading
- [x] FileTreeModel (@Observable) for sidebar state
- [x] RecentDocument SwiftData model
- [x] NavigationSplitView with sidebar + detail pane
- [x] SidebarView with recursive DisclosureGroup tree
- [x] FileWatcher (DispatchSource) for live reload
- [x] Open Folder (⇧⌘O) menu command + toolbar button
- [x] Folder persistence via @AppStorage
- [x] 34 tests passing (13 original + 14 DocumentType + 7 FileTreeNode)

#### Phase 3: Quick Look & Polish (Weeks 9-10)
- [ ] Quick Look extension target
- [ ] Register for `.md` file type
- [ ] Custom CSS theming
- [ ] Dark mode support
- [ ] Keyboard shortcuts (`j/k` scroll, `Cmd+E` edit)

#### Phase 4: Search & Release (Weeks 11-12)
- [ ] Full-text search across folder
- [ ] Favorites system
- [ ] App Store assets (screenshots, description)
- [ ] TestFlight beta
- [ ] App Store submission

---

## Testing Strategy

### VS Code Extension

#### Unit Tests
- Pattern matching logic
- Configuration parsing
- State management

#### Integration Tests
- Document open triggers preview
- Editor tab closes correctly
- Commands execute properly
- Settings respected

#### Manual Test Matrix

| Scenario | VS Code | Cursor | Windsurf |
|----------|---------|--------|----------|
| Open .md from explorer | | | |
| Open .md from quick open | | | |
| Open .md from terminal | | | |
| Excluded pattern ignored | | | |
| Edit command returns to source | | | |
| Remote SSH workspace | | | |
| WSL workspace | | | |

### macOS App

#### Unit Tests
- Markdown parsing accuracy
- Editor URL scheme generation
- Settings persistence
- Search indexing

#### Integration Tests
- File browser navigation
- "Open in Editor" launches correct app
- Quick Look extension renders correctly
- SwiftData persistence for recents/favorites

#### Manual Test Matrix

| Scenario | macOS 14 | macOS 15 |
|----------|----------|----------|
| Open single .md file | | |
| Browse folder with nested dirs | | |
| Quick Look in Finder (spacebar) | | |
| Open in Cursor | | |
| Open in Windsurf | | |
| Open in VS Code | | |
| Open in system default | | |
| Search across folder | | |
| Dark mode toggle | | |
| Large file (>1MB markdown) | | |

---

## Open Questions

### VS Code Extension

1. **Should preview replace or supplement?** — Current plan: replace. Alternative: side-by-side with source auto-collapsed.

2. **Conflict with Markdown Preview Enhanced?** — Need to test interaction; may need detection logic.

3. **Workspace vs. user settings precedence?** — Standard VS Code behavior, but document clearly.

### macOS App

4. **App Store vs. direct distribution?** — App Store gives discovery but takes 30%. Direct (via Gumroad/Paddle) keeps more revenue but requires notarization/handling updates. **Recommendation:** Start with App Store for credibility, consider direct later.

5. **Obsidian vault compatibility?** — Should Gloss understand Obsidian's `[[wiki-links]]` and render them? Would increase appeal to Obsidian users who want a lighter reader. **Recommendation:** Add in v1.1 as optional feature.

6. **iCloud sync for favorites/recents?** — Users might want reading lists synced across Macs. But adds complexity and potential privacy questions. **Recommendation:** Start without, consider for v2 if requested.

7. **iOS companion app?** — Natural extension, but significant additional work. **Recommendation:** Defer until macOS app proves demand.

### Shared

8. **Icon design** — Options: magnifying glass over document (reading), open book, stylized "G". Should feel like ORGANIZE category (teal/blue tones). Need to work at both extension icon size (128px) and macOS app icon (1024px).

9. **Shared rendering engine?** — Could the macOS app's renderer be exposed as a library for the VS Code extension? Probably overkill — VS Code has its own markdown renderer. Keep them separate.

---

## Cross-Portfolio Links

Gloss fits within the Michael Craig Group portfolio as a two-product offering demonstrating core values:

- **Privacy by architecture** — No data collection because there's no server
- **Local-first** — Everything happens on your machine
- **Sharp tools** — Does one thing well, doesn't try to be a full note-taking system
- **No subscription** — VS Code extension is free, macOS app is one-time purchase

**Follows the Zephster model:** Like Zephster (paid iOS app, privacy as differentiator), Gloss for macOS is a native app with a one-time purchase that competes on "we don't spy on you" versus free alternatives.

Related products for developers:
- **[Jotto](https://michaelcraig.group/products/jotto)** — Desktop daily notes with intelligent task forwarding
- **[Mulholland](https://michaelcraig.group/products/mulholland)** — Full filmmaking toolchain (if you're a creative)
- **[Zephster](https://michaelcraig.group/products/zephster)** — Flight tracking that tracks flights, not users

---

## Resources

### VS Code Extension
- [VS Code Extension API](https://code.visualstudio.com/api)
- [Markdown Extension Guide](https://code.visualstudio.com/api/extension-guides/markdown-extension)
- [Publishing Extensions](https://code.visualstudio.com/api/working-with-extensions/publishing-extension)
- [Extension Samples](https://github.com/microsoft/vscode-extension-samples)

### macOS App
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [SwiftData](https://developer.apple.com/documentation/swiftdata)
- [Quick Look Programming Guide](https://developer.apple.com/documentation/quicklook)
- [swift-markdown](https://github.com/apple/swift-markdown) (Apple's parser)
- [cmark](https://github.com/commonmark/cmark) (reference implementation)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

### Editor URL Schemes
- [Cursor URL Protocol](https://cursor.com) — `cursor://file/path`
- [VS Code URL Handling](https://code.visualstudio.com/docs/editor/command-line#_opening-vs-code-with-urls) — `vscode://file/path`
- Windsurf — `windsurf://file/path` (follows VS Code convention)

---

## License

MIT — Free to use, modify, and distribute.

---

*A [Michael Craig Group](https://michaelcraig.group) project — sharp tools that don't spy on you.*

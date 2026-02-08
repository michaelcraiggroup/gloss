# Gloss

> **Gloss through your markdown without touching it.**

A distraction-free markdown reader — VS Code extension and macOS app.

## Project Structure

```
gloss/
├── extension/              # VS Code extension (TypeScript)
│   ├── src/
│   │   ├── extension.ts    # Main extension entry
│   │   ├── reader/         # Custom webview reader
│   │   │   └── GlossReaderPanel.ts
│   │   └── merrily/        # Merrily integration
│   │       ├── treeProvider.ts   # Sidebar tree view
│   │       └── apiClient.ts      # Merrily API client
│   ├── package.json        # Extension manifest
│   └── tsconfig.json
├── macos/                  # macOS app (Swift/SwiftUI)
│   ├── Package.swift       # Swift Package (swift-markdown dep)
│   ├── Sources/Gloss/
│   │   ├── GlossApp.swift          # App entry point
│   │   ├── Models/
│   │   │   ├── Editor.swift        # Editor enum (Cursor, VS Code, etc.)
│   │   │   ├── AppSettings.swift   # User preferences + folder path
│   │   │   ├── DocumentType.swift  # Document classification (14 types)
│   │   │   ├── FileTreeNode.swift  # Lazy file tree node (@Observable)
│   │   │   ├── FileTreeModel.swift # Sidebar state management
│   │   │   └── RecentDocument.swift # SwiftData recent docs
│   │   ├── Views/
│   │   │   ├── ContentView.swift   # NavigationSplitView layout
│   │   │   ├── DocumentView.swift  # File loading + live reload
│   │   │   ├── SidebarView.swift   # File tree + recents sidebar
│   │   │   ├── SettingsView.swift  # Preferences window
│   │   │   └── Components/
│   │   │       ├── WebView.swift   # WKWebView wrapper
│   │   │       └── FileTreeRow.swift # Tree row with icon
│   │   ├── Services/
│   │   │   ├── MarkdownRenderer.swift  # Markdown → HTML
│   │   │   ├── EditorLauncher.swift    # External editor launch
│   │   │   └── FileWatcher.swift       # DispatchSource file watcher
│   │   └── Resources/
│   │       └── gloss-theme.css     # Ported theme from extension
│   └── Tests/GlossTests/
└── gloss-project-plan.md   # Full product plan
```

## Quick Reference

### macOS App Development

```bash
cd macos
swift build              # Build
swift test               # Run tests (34 tests)
swift run                # Launch the app
open Package.swift       # Open in Xcode, then Cmd+R
```

### Extension Development

```bash
cd extension
npm install
npm run compile      # Build TypeScript
npm run watch        # Watch mode
npm run lint         # ESLint
npm run test         # Run tests
```

**Debug in VS Code:**

- Press F5 to launch Extension Development Host
- Open any .md file to test
- Check Gloss sidebar for Merrily integration

**Package for distribution:**

```bash
npm run package      # Creates .vsix file
```

### Commands

| Command                                  | Description                   |
| ---------------------------------------- | ----------------------------- |
| `Gloss: Edit This File`                  | Switch from preview to editor |
| `Gloss: Toggle Reading Mode`             | Enable/disable globally       |
| `Gloss: Open in Reading Mode`            | Open current file in preview  |
| `Gloss: Merrily: Configure Local Folder` | Set operations docs path      |
| `Gloss: Merrily: Connect to API`         | Connect to Merrily instance   |
| `Gloss: Merrily: Disconnect`             | Disconnect from API           |

### Configuration

```jsonc
{
  // Reading mode
  "gloss.enabled": true,
  "gloss.patterns": ["**/*.md"],
  "gloss.exclude": ["**/CHANGELOG.md"],
  "gloss.zenMode": false,
  "gloss.closeSourceTab": true,

  // Merrily integration
  "gloss.merrily.localFolder": "/path/to/operations",
  "gloss.merrily.apiUrl": "http://localhost:3000",
  "gloss.merrily.apiToken": "",
}
```

## Architecture

### macOS App

The macOS app mirrors the VS Code extension's rendering approach:

1. Parses markdown with `swift-markdown` (`Document(parsing:)`)
2. Converts to HTML via `HTMLFormatter.format()`
3. Wraps in full HTML document with ported CSS theme
4. Renders in `WKWebView` via `NSViewRepresentable`
5. highlight.js for syntax highlighting (CDN in Phase 1)

Theme CSS uses CSS custom properties with `prefers-color-scheme` and explicit `html.dark`/`html.light` class overrides for app-controlled appearance.

### Reading Mode

The extension intercepts markdown file opens and:

1. Triggers the built-in markdown preview
2. Closes the source editor tab
3. Creates a "read-only by default" experience

### Merrily Integration

The sidebar tree view provides:

- **Local folder browser** — Navigate your operations folder or any folder
- **Document type icons** — Visual indicators (💡 pitch, 📊 retro, etc.)
- **API connection** — Live pitches, cycles, retrospectives from Merrily
- **Reading mode** — All documents open distraction-free

## Privacy

No telemetry, no analytics. Network requests only go to your configured Merrily instance.

## Conventions

- **Commits:** Conventional commits with emojis
- **TypeScript:** Strict mode, ESLint enforced
- **Testing:** Integration tests for VS Code API interactions

## Related Docs

- [Full Project Plan](gloss-project-plan.md)
- [Extension README](extension/README.md)
- [md+ Specification](docs/MD_PLUS_SPEC.md) - Extended markdown with executable capabilities

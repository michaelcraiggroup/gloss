# Gloss macOS App — Manual Testing Guide

> Version 1.0.0 | Last updated: 2026-03-10

## Prerequisites

1. **Build the app** (choose one):
   ```bash
   # Option A: Xcode (recommended — supports Quick Look, StoreKit testing)
   cd macos && xcodegen generate && open Gloss.xcodeproj
   # Set signing team → Cmd+R

   # Option B: SPM app bundle
   cd macos && ./Scripts/make-app.sh && open Gloss.app

   # Option C: SPM direct (limited — searchable toolbar won't work)
   cd macos && swift run
   ```

2. **Test content** — have a folder with markdown files ready. Ideally:
   - A folder with 5+ `.md` files (nested subfolders are a bonus)
   - At least one file with YAML frontmatter (`---` delimited)
   - At least one file with `[[wiki-links]]`
   - At least one file with mermaid diagrams, KaTeX math, and code blocks
   - A file with multiple headings (h1–h6)

   If you don't have these, use the `gloss/` repo itself — `CLAUDE.md`, `gloss-project-plan.md`, and `extension/README.md` are good candidates.

---

## 1. App Launch & Window

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 1.1 | Launch Gloss | Window opens with empty state or last folder | |
| 1.2 | Check menu bar | "Gloss" menu with About, Settings, Quit | |
| 1.3 | Resize window | Layout adapts, sidebar collapses at narrow widths | |
| 1.4 | Check dark mode (System Settings → Appearance → Dark) | App switches to dark theme | |
| 1.5 | Check light mode | App switches to light theme | |

---

## 2. File Opening (Free Tier)

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 2.1 | File > Open (⌘O) → select a `.md` file | File renders in main view | |
| 2.2 | Drag a `.md` file onto the app window | File renders | |
| 2.3 | Drag a `.md` file onto the Dock icon | File opens and renders | |
| 2.4 | Double-click a `.md` file in Finder (if Gloss is default) | Gloss opens and renders | |
| 2.5 | Open a non-`.md` file | Graceful handling (ignored or error) | |

---

## 3. Document Rendering

### 3a. Basic Rendering

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 3.1 | Open a file with headings (h1–h6) | All heading levels render with correct sizes | |
| 3.2 | Bold, italic, strikethrough | Inline formatting renders correctly | |
| 3.3 | Bullet lists, numbered lists | Lists render with proper indentation | |
| 3.4 | Links `[text](url)` | Render as clickable links | |
| 3.5 | Images `![alt](path)` | Images render (if path is accessible) | |
| 3.6 | Blockquotes `>` | Styled with left border | |
| 3.7 | Horizontal rules `---` | Renders as separator line | |
| 3.8 | Tables | Renders with borders, header row styled | |

### 3b. Code

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 3.9 | Inline code `` `code` `` | Monospace with background | |
| 3.10 | Fenced code block (```swift) | Syntax highlighted with language colors | |
| 3.11 | Hover over code block | Copy button appears in top-right corner | |
| 3.12 | Click copy button | Code copied to clipboard (paste to verify) | |

### 3c. Mermaid Diagrams

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 3.13 | Open a file with ` ```mermaid ` block | Diagram renders as SVG (not raw text) | |
| 3.14 | Flowchart, sequence, gantt | Various diagram types render | |
| 3.15 | Dark mode mermaid | Diagram adapts to dark theme | |

### 3d. KaTeX Math

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 3.16 | Inline math `$E = mc^2$` | Renders as formatted equation inline | |
| 3.17 | Display math `$$\int_0^1 x^2 dx$$` | Renders as centered block equation | |

### 3e. Heading Anchors

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 3.18 | Hover over any heading | `#` anchor link appears to the left | |
| 3.19 | Click the `#` anchor | Page scrolls/jumps to that heading (URL updates) | |

### 3f. Frontmatter

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 3.20 | Open file with YAML frontmatter (`---` block) | Frontmatter is NOT shown in rendered output | |
| 3.21 | Verify frontmatter is parsed | Inspector sidebar shows frontmatter data (paid) | |

### 3g. Wiki-Links

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 3.22 | Open file with `[[target]]` syntax | Renders as clickable link with text "target" | |
| 3.23 | `[[target\|display text]]` | Renders as clickable link with text "display text" | |
| 3.24 | Click a wiki-link (paid feature) | Navigates to target file if found in folder | |

### 3h. External Links

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 3.25 | Click an `http://` or `https://` link | Opens in default browser, NOT in Gloss | |

---

## 4. Live Reload

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 4.1 | Open a file in Gloss, then edit it in another app | Gloss updates rendering automatically | |
| 4.2 | Save changes in external editor | Content refreshes without manual reload | |

---

## 5. Keyboard Navigation (Free Tier)

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 5.1 | Press `j` | Scroll down | |
| 5.2 | Press `k` | Scroll up | |
| 5.3 | Press `Space` | Page down | |
| 5.4 | Press `Shift+Space` | Page up | |
| 5.5 | Press `gg` (two g's quickly) | Jump to top | |
| 5.6 | Press `G` (shift+g) | Jump to bottom | |

---

## 6. Open in Editor (Free Tier)

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 6.1 | Cmd+E with a file open | Opens current file in configured editor | |
| 6.2 | Settings → Editor → change editor | Editor picker shows Cursor, VS Code, etc. | |
| 6.3 | Cmd+E after changing editor | Opens in newly selected editor | |

---

## 7. Dark/Light Theme (Free Tier)

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 7.1 | Settings → Appearance → Dark | App switches to dark theme | |
| 7.2 | Settings → Appearance → Light | App switches to light theme | |
| 7.3 | Settings → Appearance → System | Follows macOS system setting | |
| 7.4 | Toggle macOS system appearance | App follows if set to System | |

---

## 8. Folder Sidebar (Paid Feature)

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 8.1 | Click "Open Folder" in sidebar (while locked) | Paywall appears | |
| 8.2 | Purchase/unlock → Open Folder | Folder picker opens, tree populates sidebar | |
| 8.3 | Click a `.md` file in tree | File renders in detail view | |
| 8.4 | Expand/collapse folders | Tree nodes toggle correctly | |
| 8.5 | Sidebar search (filename filter) | Tree filters to matching files | |
| 8.6 | Navigate nested folders | Deep nesting works, lazy loading | |

---

## 9. Full-Text Search (Paid Feature)

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 9.1 | Switch search scope to "Content" (while locked) | Paywall appears | |
| 9.2 | After unlock, type in search bar with Content scope | Results show files with matching content | |
| 9.3 | Click a search result | File opens with content visible | |
| 9.4 | Search with no matches | Empty state / "no results" | |

---

## 10. Favorites & Recents (Paid Feature)

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 10.1 | Cmd+D on an open file (while locked) | Paywall appears | |
| 10.2 | After unlock, Cmd+D | Star appears, file added to Favorites | |
| 10.3 | Cmd+D again | Star removed, file removed from Favorites | |
| 10.4 | Check Recents section in sidebar | Recently opened files listed | |
| 10.5 | Click a recent/favorite | File opens | |

---

## 11. Find-in-Page (Paid Feature)

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 11.1 | Cmd+F (while locked) | Paywall appears | |
| 11.2 | After unlock, Cmd+F | Find bar appears at top of document | |
| 11.3 | Type search term | Matches highlighted in document | |
| 11.4 | Cmd+G | Jump to next match | |
| 11.5 | Shift+Cmd+G | Jump to previous match | |
| 11.6 | Match counter | Shows "X of Y" count | |
| 11.7 | Escape or close find bar | Highlights cleared | |

---

## 12. Inspector Sidebar (Paid Feature)

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 12.1 | Cmd+Option+I (while locked) | Paywall appears | |
| 12.2 | After unlock, Cmd+Option+I | Inspector panel opens on right side | |
| 12.3 | TOC section | Lists all headings from current document | |
| 12.4 | Click a heading in TOC | Document scrolls to that heading | |
| 12.5 | Heading indentation | h2 indented under h1, h3 under h2, etc. | |
| 12.6 | Frontmatter section | Shows parsed YAML key-value pairs | |
| 12.7 | Switch to file without frontmatter | Frontmatter section empty or hidden | |
| 12.8 | Cmd+Option+I again | Inspector closes | |

---

## 13. Print (Paid Feature)

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 13.1 | Cmd+P (while locked) | Paywall appears | |
| 13.2 | After unlock, Cmd+P | macOS print dialog appears | |
| 13.3 | Print to PDF via system dialog | Clean output without UI chrome | |

---

## 14. PDF Export (Paid Feature)

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 14.1 | File > Export as PDF (while locked) | Paywall appears | |
| 14.2 | After unlock, File > Export as PDF | Save panel appears | |
| 14.3 | Choose location and save | PDF created with rendered markdown | |
| 14.4 | Open exported PDF | Content matches rendered view | |

---

## 15. Font Size (Paid Feature)

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 15.1 | Settings → Font Size stepper (while locked) | Paywall appears, value reverts | |
| 15.2 | After unlock, increase font size | Text in document grows | |
| 15.3 | Decrease font size | Text shrinks | |
| 15.4 | Range: 12–24px | Stepper stops at bounds | |

---

## 16. StoreKit Paywall

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 16.1 | Trigger any paid feature while locked | PaywallView sheet appears | |
| 16.2 | Paywall shows feature list | 7+ features with checkmarks | |
| 16.3 | Paywall shows price | "$4.99" (from StoreKit config) | |
| 16.4 | Tap "Unlock Gloss Full" | Purchase flow (StoreKit sandbox) | |
| 16.5 | After purchase, all paid features unlock | No more paywall triggers | |
| 16.6 | "Restore Purchase" button | Restores previous purchase | |
| 16.7 | Dismiss paywall without purchasing | Sheet closes, feature stays locked | |

---

## 17. Quick Look Extension

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 17.1 | In Finder, select a `.md` file and press Space | Quick Look preview shows rendered markdown | |
| 17.2 | Headings, code blocks, lists render | Full Gloss styling applied | |
| 17.3 | Dark mode Quick Look | Follows system appearance | |
| 17.4 | Close Quick Look (Space or Escape) | Preview dismisses | |

> **Note:** Quick Look requires the app to be built via Xcode (not SPM) and properly signed. The extension must be registered with the system — you may need to run the app once first.

---

## 18. Settings

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 18.1 | Cmd+, | Settings window opens | |
| 18.2 | Editor section | Editor picker with multiple options | |
| 18.3 | Appearance section | Dark/Light/System toggle | |
| 18.4 | Settings persist after quit+relaunch | Values retained | |

---

## 19. Edge Cases

| # | Test | Expected | ✅ |
|---|------|----------|----|
| 19.1 | Open empty `.md` file | Blank render, no crash | |
| 19.2 | Open very large `.md` file (1000+ lines) | Renders without hang | |
| 19.3 | File with no headings → check inspector TOC | TOC section empty | |
| 19.4 | File with broken YAML frontmatter | Renders content, frontmatter parsing graceful | |
| 19.5 | Wiki-link to non-existent file | Link renders but navigation fails gracefully | |
| 19.6 | Rapid file switching in sidebar | No crashes, correct file always shown | |
| 19.7 | Quit and relaunch | Last state partially restored | |

---

## Testing Notes

- **StoreKit testing**: When built via Xcode with the `GlossStore.storekit` config, purchases are simulated locally. No real charges. Use Xcode's Debug > StoreKit > Manage Transactions to reset purchases between test runs.
- **Quick Look registration**: After building in Xcode, the QL extension registers automatically. If it doesn't work, try: `qlmanage -r` to reset the QL cache, then relaunch Finder.
- **Two build modes**: Some features (searchable toolbar, StoreKit) only work properly via Xcode or `make-app.sh`, not `swift run`.

# Gloss macOS App — Developer Test Plan

Pre-release manual testing checklist. Run through on both macOS 14 and macOS 15 if possible.

---

## 1. App Launch & Window

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 1.1 | Cold start | Launch app with no prior state | Empty detail pane: doc.text icon, "Open a markdown file to start reading" |
| 1.2 | Window sizing | Resize below 600×400 | Window enforces minimum size |
| 1.3 | Default size | Fresh launch, check window dimensions | ~1000×700 |
| 1.4 | Sidebar toggle | Click sidebar toggle in toolbar | Sidebar collapses/expands |
| 1.5 | Settings window | ⌘, | Settings opens at ~350×220, three sections visible |
| 1.6 | Folder restore | Open a folder, quit, relaunch | Same folder reopened in sidebar automatically |
| 1.7 | Missing folder restore | Open folder, quit, delete folder, relaunch | App opens with empty state (no crash) |

---

## 2. File Opening

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 2.1 | Open file (⌘O) | File → Open, select a .md file | File renders in detail pane, filename in toolbar |
| 2.2 | Open non-markdown | File → Open, try selecting a .txt or .swift | Panel should filter to plainText types; non-markdown may still open |
| 2.3 | Drag & drop .md | Drag a .md file onto the detail pane | File opens and renders |
| 2.4 | Drag & drop non-md | Drag a .png or .txt onto the detail pane | Ignored (no action) |
| 2.5 | Open folder (⇧⌘O) | File → Open Folder, select a directory | Folder appears in sidebar with tree |
| 2.6 | Close folder | File → Close Folder | Sidebar tree cleared |
| 2.7 | Close folder disabled | No folder open, check menu | "Close Folder" is grayed out |
| 2.8 | Large file | Open a markdown file >500KB | Renders without hang (may take a moment) |
| 2.9 | Empty file | Open a 0-byte .md file | Renders without error (blank content) |
| 2.10 | Unicode content | Open .md with CJK, emoji, RTL text | Renders correctly with proper encoding |

---

## 3. Sidebar — File Tree

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 3.1 | Tree structure | Open a folder with nested subdirectories | Directories show disclosure arrows, files show type icons |
| 3.2 | Lazy loading | Click disclosure on a deep folder | Children load on first expand only |
| 3.3 | Sort order | Check tree with mixed files/folders | Directories first (alphabetical), then files (alphabetical) |
| 3.4 | Hidden files excluded | Folder containing .git, .DS_Store, node_modules | None of these appear in tree |
| 3.5 | File selection | Click a .md file in tree | File opens in detail pane, toolbar updates |
| 3.6 | Extension stripping | Files named "README.md", "plan.markdown" | Display as "README", "plan" (no extension) |
| 3.7 | Document type icons | Folder with pitches/, strategies/, readme.md | 💡, 🎯, 📖 icons shown correctly |
| 3.8 | Folder icon | Directories in tree | Show 📂 icon |
| 3.9 | Context menu — favorite | Right-click a file in tree | "Add to Favorites" option; adds file to favorites section |
| 3.10 | Open Folder button | Click folder.badge.plus in sidebar toolbar | Opens folder panel (same as ⇧⌘O) |

---

## 4. Sidebar — Search (Filenames)

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 4.1 | Search bar focus | Click search bar in sidebar | Cursor appears, scope pills visible below |
| 4.2 | Filename search | Type "read" with Filenames scope | Shows matching files (e.g., README.md) in flat list |
| 4.3 | Case insensitive | Type "READ" or "Read" | Same results as lowercase |
| 4.4 | No matches | Type a nonsense query | "No matches" message |
| 4.5 | Clear search | Delete all text from search bar | Returns to normal browse mode (tree + favorites + recents) |
| 4.6 | Deep match | Search for file that exists 3+ levels deep | Found and displayed in flat results |

---

## 5. Sidebar — Search (Content)

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 5.1 | Switch scope | Click "Content" scope pill | Scope changes; search re-triggers if query present |
| 5.2 | Content search | Type a word that appears in file bodies | Results show filename, line number (L42), line preview |
| 5.3 | Progress indicator | Type query, watch immediately | ProgressView + "Searching..." appears briefly |
| 5.4 | Debounce | Type quickly, pause 300ms | Only one search executes after pause |
| 5.5 | Result click | Click a content search result | File opens in detail pane |
| 5.6 | Max 100 results | Search a common word in a large folder | Results capped at 100 |
| 5.7 | Line truncation | Result with a very long line (>200 chars) | Preview truncated, no layout break |
| 5.8 | Switch back to filename | Click "Filenames" scope pill | Content results cleared, filename mode restored |
| 5.9 | Empty folder search | Open empty folder, search content | "No matches" shown |

---

## 6. Favorites

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 6.1 | Add via ⌘D | Open a file, press ⌘D | Star fills yellow in toolbar; file appears in Favorites section |
| 6.2 | Remove via ⌘D | Press ⌘D again on same file | Star unfills; file removed from Favorites section |
| 6.3 | Add via toolbar | Click star button in toolbar | Same as ⌘D |
| 6.4 | Add via context menu | Right-click file in tree → "Add to Favorites" | File appears in Favorites section |
| 6.5 | Remove via swipe | Swipe left on a favorite in Favorites section | Removed from favorites |
| 6.6 | Star in recents | Click star icon next to a recent document | Toggles favorite status |
| 6.7 | Favorites section hidden | No favorites exist | "Favorites" section not shown in sidebar |
| 6.8 | Favorites sorting | Favorite multiple files | Listed alphabetically by title |
| 6.9 | Favorite persistence | Favorite a file, quit, relaunch | Favorite still present |
| 6.10 | Favorite deleted file | Favorite a file, delete it from disk, click favorite | Error state shown in detail pane |
| 6.11 | ⌘D disabled | No file selected, check menu | "Toggle Favorite" grayed out |

---

## 7. Recent Documents

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 7.1 | Auto-tracking | Open several files | Each appears in "Recent Documents" section |
| 7.2 | Ordering | Open files A, B, C in order | C shown first (most recent) |
| 7.3 | Limit | Open 15+ distinct files | Only 10 most recent shown |
| 7.4 | Revisit updates order | Open file A again | A moves to top of recents |
| 7.5 | Click to reopen | Click a recent document | File opens in detail pane |
| 7.6 | Persistence | Open files, quit, relaunch | Recents preserved |

---

## 8. Rendering

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 8.1 | Headings | File with h1-h6 | All heading levels render with correct sizing |
| 8.2 | Code blocks | File with fenced code blocks (```js, ```python) | Syntax highlighted via highlight.js |
| 8.3 | Inline code | Text with `inline code` | Styled with code background |
| 8.4 | Tables | File with GFM tables | Rendered as HTML table with borders |
| 8.5 | Blockquotes | File with > blockquotes | Styled with left border accent |
| 8.6 | Links | File with [links](url) | Rendered as clickable links |
| 8.7 | Images | File with ![alt](url) | Images loaded and displayed |
| 8.8 | Lists | Ordered and unordered lists, nested | Proper indentation and bullets/numbers |
| 8.9 | Bold/Italic | **bold**, *italic*, ***both*** | Correct emphasis rendering |
| 8.10 | Horizontal rules | --- or *** | Rendered as styled separator |

---

## 9. Copy Buttons

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 9.1 | Button appears | Hover over a code block | "Copy" button visible in top-right corner |
| 9.2 | Copy action | Click "Copy" button | Code text copied to system clipboard |
| 9.3 | Feedback | After clicking | Button text changes to "Copied!" for ~2 seconds |
| 9.4 | Multi-block | File with multiple code blocks | Each has its own independent copy button |
| 9.5 | Clipboard verify | Copy, then paste in another app | Correct code text pasted |

---

## 10. Keyboard Navigation (Vim-style)

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 10.1 | j scroll down | Press j | Page scrolls down ~100px smoothly |
| 10.2 | k scroll up | Press k | Page scrolls up ~100px smoothly |
| 10.3 | Space page down | Press Space | Scrolls down ~80% of viewport |
| 10.4 | Shift+Space page up | Press Shift+Space | Scrolls up ~80% of viewport |
| 10.5 | gg jump to top | Press g, then g within 500ms | Scrolls to top of document |
| 10.6 | G jump to bottom | Press Shift+G | Scrolls to bottom of document |
| 10.7 | Modifier ignored | Hold ⌘ and press j | No scroll (modifier keys suppress vim nav) |
| 10.8 | Input focus guard | Open find bar, type j/k in search field | Characters type into field (no scrolling) |
| 10.9 | First responder | Open a file, immediately press j | WebView has focus; scrolling works without clicking first |

---

## 11. Find-in-Page

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 11.1 | Toggle bar | ⌘F | Find bar appears at top of rendered content |
| 11.2 | Search | Type a word in find bar | Matches highlighted yellow; current match teal; counter shows "1 / N" |
| 11.3 | Find Next | ⌘G or Enter in find bar or ▼ button | Advances to next match; counter updates; scrolls into view |
| 11.4 | Find Previous | ⇧⌘G or Shift+Enter or ▲ button | Goes to previous match |
| 11.5 | Wrap around | Navigate past last match | Wraps to first match |
| 11.6 | Close bar | Press Escape or ✕ button | Bar hides; highlights removed; input cleared |
| 11.7 | No matches | Search for nonexistent text | "No matches" shown in counter area |
| 11.8 | Case insensitive | Search "the" vs "THE" | Same matches found |
| 11.9 | File change | Find bar open, click different file in sidebar | New file loads; find bar persists but highlights cleared |
| 11.10 | Vim keys during find | Find bar focused, press j/k | Types into find input (does not scroll) |

---

## 12. Theme & Appearance

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 12.1 | System theme | Settings → Theme: System | Follows macOS dark/light mode |
| 12.2 | Force dark | Settings → Theme: Dark | App + rendered content switch to dark theme |
| 12.3 | Force light | Settings → Theme: Light | App + rendered content switch to light theme |
| 12.4 | System switch | Theme: System, toggle macOS appearance in System Settings | App follows immediately |
| 12.5 | Dark colors | Dark mode | bg #1e1e1e, fg #d4d4d4, code-bg #2d2d2d |
| 12.6 | Light colors | Light mode | bg #ffffff, fg #333333, code-bg #f5f5f5 |
| 12.7 | Code highlighting | Dark vs Light mode code blocks | github-dark theme in dark, github theme in light |

---

## 13. Font Size

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 13.1 | Default | Fresh install | Body text renders at 16px |
| 13.2 | Increase | Settings → Font size stepper up to 24 | Text enlarges; re-renders on change |
| 13.3 | Decrease | Settings → Font size stepper down to 12 | Text shrinks; re-renders on change |
| 13.4 | Boundary — min | Try stepping below 12 | Stepper stops at 12 |
| 13.5 | Boundary — max | Try stepping above 24 | Stepper stops at 24 |
| 13.6 | Persistence | Change font size, quit, relaunch, open a file | Font size preserved |

---

## 14. Open in Editor

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 14.1 | Cursor | Settings: Cursor, open file, ⇧⌘E | File opens in Cursor at correct path |
| 14.2 | VS Code | Settings: VS Code, ⇧⌘E | File opens in VS Code |
| 14.3 | System Default | Settings: System Default, ⇧⌘E | File opens in default .md handler |
| 14.4 | Toolbar button | Click pencil.and.outline button | Same as ⇧⌘E |
| 14.5 | Disabled state | No file open, check toolbar + menu | Both "Open in Editor" controls disabled |
| 14.6 | Help text | Hover toolbar button | Tooltip shows "Open in [Editor] (⇧⌘E)" |

---

## 15. Live Reload

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 15.1 | Edit externally | Open file in Gloss, edit + save in external editor | Gloss re-renders updated content automatically |
| 15.2 | Multiple edits | Save the file 3 times rapidly | Each save triggers reload; final state correct |
| 15.3 | Switch files | Open file A, then file B, edit file A externally | File B still shown (A's watcher was replaced) |
| 15.4 | Delete watched file | Open file, delete it from Finder | Error state shown in detail pane |

---

## 16. Quick Look Extension

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 16.1 | Basic preview | In Finder, select a .md file, press Space | Gloss-themed markdown preview appears |
| 16.2 | Theme follows system | Toggle macOS dark/light mode, preview a .md file | Preview matches system appearance |
| 16.3 | Code blocks | Preview a file with code blocks | Syntax highlighted, copy buttons present |
| 16.4 | Large file | Preview a large .md file | Renders without timeout |
| 16.5 | Extension registered | Check System Settings → Extensions → Quick Look | GlossQL listed |

> **Note:** Quick Look extension requires the signed app to be installed (or run from Xcode with signing). It won't work from `swift run`.

---

## 17. Sandbox & Permissions

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 17.1 | File access | Open a file via ⌘O | Access granted (user-selected read-only) |
| 17.2 | Folder access | Open a folder via ⇧⌘O | Full tree readable |
| 17.3 | No write access | App should never modify opened files | Verify: no save/edit capability exists |
| 17.4 | Network — highlight.js | Open file with code blocks | highlight.js loads from CDN (network.client entitlement) |
| 17.5 | Restricted paths | Try opening /etc/ or /System/ | Files readable if user selects them via panel |

---

## 18. Edge Cases & Stress

| # | Test | Steps | Expected |
|---|------|-------|----------|
| 18.1 | Deeply nested folder | Open folder with 10+ levels of nesting | Tree navigable, no stack overflow |
| 18.2 | Thousands of files | Open a folder with 1000+ markdown files | Sidebar loads without freeze (lazy loading) |
| 18.3 | Symlinks | Folder containing symlinks to files/dirs | Symlinks followed or gracefully skipped |
| 18.4 | Special characters | File named "résumé (copy).md" | Opens and displays correctly |
| 18.5 | Spaces in path | Folder at "/Users/me/My Documents/notes/" | Tree and file opening work correctly |
| 18.6 | Memory pressure | Open 20+ different files in sequence | No memory leak (check Activity Monitor) |
| 18.7 | Rapid file switching | Click through files quickly in sidebar | Each file renders, no stale content shown |
| 18.8 | Quit during search | Start content search, immediately ⌘Q | Clean quit, no crash |

---

## Summary

| Section | Tests | Priority |
|---------|-------|----------|
| 1. App Launch & Window | 7 | High |
| 2. File Opening | 10 | High |
| 3. Sidebar — File Tree | 10 | High |
| 4. Search — Filenames | 6 | Medium |
| 5. Search — Content | 9 | Medium |
| 6. Favorites | 11 | Medium |
| 7. Recent Documents | 6 | Medium |
| 8. Rendering | 10 | High |
| 9. Copy Buttons | 5 | Medium |
| 10. Keyboard Navigation | 9 | Medium |
| 11. Find-in-Page | 10 | Medium |
| 12. Theme & Appearance | 7 | High |
| 13. Font Size | 6 | Low |
| 14. Open in Editor | 6 | Medium |
| 15. Live Reload | 4 | High |
| 16. Quick Look Extension | 5 | High |
| 17. Sandbox & Permissions | 5 | High |
| 18. Edge Cases & Stress | 8 | Medium |
| **Total** | **138** | |

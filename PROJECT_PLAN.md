---
project: "gloss"
title: "Gloss — A knowledgebase that opens to read"
status: "active"
phase: "Knowledgebase (Path B) — M1: Query layer"
progress: 62
stack: "Swift/SwiftUI (macOS app, GlossKit), TypeScript (VS Code extension)"
strategic_direction: "Path B — become a full knowledgebase (queries, transclusion, capture, properties, sync, iOS). Reader-first survives as the differentiator: it opens to read."
next_steps:
  - "M1: type:query md+ block over LinkDatabase"
  - "M1: frontmatter properties table in .gloss/index.sqlite"
  - "M1: saved searches in sidebar"
  - "M2: transclusion, unlinked mentions, [[ autocomplete"
open_questions:
  - "Sync = the user's own iCloud (confirm) — keeps the no-subscription promise"
  - "Positioning revisit when M3 capture ships"
  - "Pricing under KB scope — leaning all one-time, iCloud sync free"
last_updated: "2026-06-30"
---

# Gloss — Project Plan

> **Like Preview.app, but for markdown.** Opens to read; edits when you ask.

A distraction-free markdown reader — VS Code extension and macOS app — on a path to become a **privacy-first, local-first knowledgebase** that opens to read.

📋 Roadmap: [plans/gloss/2026-06-30-knowledgebase-path-b.md](../mcg-operations/plans/gloss/2026-06-30-knowledgebase-path-b.md)
📖 Full product history: [gloss-project-plan.md](gloss-project-plan.md)

## Strategic Direction — Path B: become the knowledgebase

Gloss already owns the *navigation* half of a knowledgebase: typed wiki-links (`[[concept::relates]]`), backlinks, tags + filtering, full-text search, a D3 force-directed graph, and a persistent **SQLite link index** (`.gloss/index.sqlite`). With Jotto re-created as **Syncopate** (a task manager), capture no longer cannibalizes a sibling — so Gloss commits to **Path B**: a full knowledgebase, not a reader-only tool.

**Reconciliations:**

- **Positioning survives.** Every other knowledgebase opens into an editor; Gloss opens to *read*. The line evolves toward *"the knowledgebase that opens to read."* Reader-first is the category differentiator, not a scope limit.
- **No subscription, still.** Sync = the user's **own iCloud** (plain-markdown vault, zero server cost, more private). The one-time-price promise holds.
- **md+ is the spine.** Queries, embeds, and templates are md+ blocks — *"markdown that's alive,"* not an Obsidian clone.

## Knowledgebase roadmap (M1 → M5)

| Milestone | Unlocks | Builds on | Cost |
|---|---|---|---|
| **M1 · Query layer** | interrogate the corpus | `LinkDatabase` + md+ | Low |
| **M2 · Compose & densify** | transclusion, unlinked mentions, `[[` autocomplete | index + WKWebView + CM6 | Low–Med |
| **M3 · Capture & properties** | daily notes, quick capture, editable fields | SwiftData + index | Med |
| **M4 · Durability & reach** | iCloud sync, version history, iOS | GlossKit + iCloud | High |
| **M5 · Parity polish** | panes/tabs, folding, nested tags | app shell | Ongoing |

### M1 — Query layer (current — spec in review)
- [ ] `type: query` md+ block over `LinkDatabase` (tags, links, frontmatter fields)
- [ ] Frontmatter **properties** table in `.gloss/index.sqlite`, populated by `LinkIndex`
- [ ] Saved searches in the sidebar
- [ ] Detailed spec: see archived roadmap + plan-mode signoff

### M2 — Compose & densify
- [ ] Transclusion: `![[note]]` / `![[note#heading]]` inline (read mode)
- [ ] Unlinked mentions panel in the inspector
- [ ] `[[` autocomplete in the CM6 editor

### M3 — Capture & properties
- [ ] Daily notes + calendar navigation
- [ ] Quick capture (menu-bar `NSStatusItem` + global hotkey)
- [ ] Editable frontmatter properties (write back + re-index)

### M4 — Durability & reach
- [ ] iCloud sync (markdown only; exclude `.gloss/` derived cache)
- [ ] Version history (local snapshots / git-backed)
- [ ] iOS companion (read + capture; reuses GlossKit renderer)

### M5 — Parity polish
- [ ] Split panes / tabs
- [ ] Outline folding
- [ ] Hierarchical tags

## Status (2026-06-30)

**Reader + light-KB foundation: shipped** (macOS app through v1.11.2) — rendering (syntax / Mermaid / KaTeX), folder sidebar, full-text search, Quick Look, find / print / PDF, editor mode (CM6 live preview), file CRUD, typed wiki-links + backlinks, tags UI + filtering, GRDB SQLite link index, force-directed graph, md+ fillable templates, feature walkthroughs. **283 tests.**

**In flight — PR [#16](https://github.com/michaelcraiggroup/gloss/pull/16) (Chiat\Day pre-launch pass):** feature-gating copy reconciliation, version sync → v1.11.3, reader-first positioning + standardized tagline, **amber brand** recolor.

**Next — Path B, M1:** the query layer.

## VS Code extension

Free / MIT — published. Trust-builder and funnel to the macOS app.

## Cross-project integrations

- **Syncopate (tasks):** a `type: query` block could surface Syncopate tasks tied to a note (notes ↔ tasks). A Syncopate MCP exists.
- **nocmeout (runbooks):** Gloss as the rendering layer for operational runbooks via md+ `shell` / `chart` blocks (depends on md+ shell + trust config). See `docs/MD_PLUS_SPEC.md`.

---

_Full product history and the original phase-by-phase plan: [gloss-project-plan.md](gloss-project-plan.md). md+ design: [docs/MD_PLUS_SPEC.md](docs/MD_PLUS_SPEC.md)._

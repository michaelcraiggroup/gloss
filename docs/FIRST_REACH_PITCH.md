# Gloss: The First Thing You Reach For

> A creative brief for positioning Gloss as the default starting point for knowledge work.

**Status:** Draft
**Date:** 2026-03-18
**Audience:** Creatives, knowledge workers, team leads, anyone who lives in markdown

---

## The Insight

Every tool on your dock assumes it knows what you're about to do. Word processors assume you're writing. Search tools assume you're finding. Task managers assume you're executing. But the truth is — when you sit down, you often don't know yet.

You might be about to **create**. You might be about to **find**. You might be about to **read deeply**. You might be about to **sign off on something**. The intent is forming. The tool shouldn't force a commitment before you've made one.

Gloss is the app for that moment — the moment before the moment. The first reach.

---

## The Four Intents

When someone reaches for Gloss, one of four things is about to happen. The interface serves all four without making you choose upfront.

### 1. Create — "I need to get something down."

A new document. A blank page. The cursor blinks.

Gloss opens into a live-preview editor (Cmd+Shift+E) that renders your markdown as you write — headings scale, bold appears bold, links become links — but the syntax stays accessible on the line you're editing. It's Obsidian-style live preview without Obsidian's weight. You're writing markdown, but you're *seeing* the document.

No template picker. No format dialog. No font menu. Just the thought and the page.

**The bet:** Removing friction at the point of creation means more things get written. The best authoring tool is the one that doesn't make you think about authoring.

### 2. Research — "I need to find something."

Full-text search across your entire vault. Wiki-links that connect ideas across documents. A link index with typed relationships — `[[concept::relates]]`, `[[source::cites]]`, `[[decision::supports]]`. Backlinks in the inspector that show you not just *what* links here, but *why*.

Tags extracted from frontmatter. Content search with debounced async results. Everything indexed in a local SQLite database that never leaves your machine.

**The bet:** Research is just reading with intent. The same sidebar, the same inspector, the same navigation — but now the question "where did I put that?" has an answer in milliseconds.

### 3. Deep Read — "I need to understand this."

This is where Gloss started, and it shows. Rendered markdown with a proper type stack — heading hierarchy, code blocks with syntax highlighting, Mermaid diagrams, KaTeX math. Table of contents in the inspector. Frontmatter metadata visible but not intrusive. Keyboard navigation (vim-style: j/k/gg/G) so your hands never leave the keyboard.

Dark mode. Light mode. Font size control. Print to PDF. Find-in-page. The reading experience is the product.

**The bet:** Most markdown tools optimize for writing and treat reading as an afterthought. Gloss inverts that. When the reading experience is excellent, people trust the tool enough to write in it.

### 4. Follow Through — "I need to check this off."

Procedural checklists. Runbooks. Review documents. The kind of markdown that exists not to be *read* but to be *followed* — step by step, box by box.

GFM task lists render as checkboxes. The editor makes them interactive. Wiki-links connect the checklist to the supporting documents. The inspector shows you where you are in the structure. You're not just reading a process — you're executing it.

**The bet:** Checklists are the connective tissue between knowledge and action. A tool that handles both the reference material *and* the checklist becomes the single pane of glass for getting things done.

---

## Why This Works

### The TBWA Lens

At Chiat\Day, we called it "disruption" — finding the convention, then breaking it. The convention in productivity tools is specialization: one tool writes, another searches, another manages tasks, another reads. The user becomes a switchboard operator, routing their own intent to the right app.

Gloss disrupts by **refusing to specialize**. It's a reader that edits. A writer that searches. A browser that checks boxes. The markdown file is the universal format, and Gloss is the universal interface to it.

This isn't a Swiss Army knife (too many blades, none sharp). It's a *lens*. You point it at your markdown and it shows you what you need to see, lets you do what you need to do.

### The Privacy Angle

Every feature runs locally. The link index is a SQLite file on your disk. Search doesn't phone home. There's no sync layer to breach, no cloud to subpoena, no analytics to scrape.

For creatives, this matters. Drafts are vulnerable. Ideas in formation are fragile. The tool that touches your thinking should be the tool you trust the most.

### The Economics

Free download. $4.99 one-time purchase to unlock the power features — sidebar, search, inspector, wiki-links, print. No subscription. No ads. Ever.

Quick Look is free — every time someone presses spacebar on a .md file in Finder, Gloss renders it beautifully. That's the hook. The conversion happens naturally: "I want to browse a whole folder like that."

---

## The Line

> **Gloss through your markdown without touching it.**

It still works. But now there's a second read:

> **Gloss** — the first thing you reach for.

The name carries both meanings. A gloss is a reading — a layer of understanding over a text. And to gloss is to move fluidly through material, eyes and mind engaged. Both are true. Both describe the product.

---

## Competitive Position

| Tool | Writes | Reads | Searches | Checklists | Local | Price |
|------|--------|-------|----------|------------|-------|-------|
| **Gloss** | Yes | **Excellent** | Yes | Yes | **100%** | $4.99 once |
| Obsidian | Yes | Good | Yes | Plugin | Local | $50/yr (sync) |
| Typora | Yes | Good | Basic | No | Local | $14.99 |
| iA Writer | Yes | Good | No | No | iCloud | $49.99 |
| Marked 2 | No | Excellent | No | No | Local | $13.99 |
| VS Code + ext | Yes | OK | Yes | No | Local | Free |

Gloss is the only tool in this space that was **designed for reading first** and added writing second. That's not a limitation — it's the insight. Everyone else builds a writing tool and bolts on preview. Gloss builds a reading experience and lets you edit in place.

---

## Next Moves

1. **md+ interactive checklists** — fillable templates where checkboxes persist state, turning Gloss into a lightweight workflow tool
2. **Navigation history** — back/forward for wiki-link browsing, making research sessions feel like web browsing
3. **Custom editor picker** — "Open in [your tool]" for the heavy lifting, Gloss for everything else

---

*"The work you're most proud of started as a messy draft in a tool that got out of your way."*

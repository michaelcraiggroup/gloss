---
title: Gloss — App Store Readiness Evaluation & Submission Plan
tags: [app-store, release, qa, checklist]
status: active
version-under-test: 1.23.0
updated: 2026-08-05
---

# Gloss — App Store Readiness

**Verdict as of 2026-08-05: not ready to submit — but nothing structural is wrong.**

The app is feature-complete and stable (385 tests, 45 suites, green on `swift test`). What blocks
submission is a short list of things *around* the app: two required listing URLs return 404, the
bundle is missing a key the Mac App Store requires, there is no Mac App Store build path (only
Developer ID + notarization), the listing describes a version of Gloss that no longer matches the
one you'd ship, and no signed build has ever been through a full verification pass.

Estimated work to a submittable state: **~8–12 focused hours**, most of it verification, plus
whatever the two website pages take in the `goose` repo.

## How to use this document

Three parts, meant to be run top to bottom:

1. **[Part 1 — Feature evaluation](#part-1--feature-by-feature-evaluation)**: what actually ships,
   verified against source, and whether the App Store listing tells the truth about it.
2. **[Part 2 — Blocker board](#part-2--blocker-board)**: everything that must be true before you
   press Submit, each with evidence, fix, and effort.
3. **[Part 3 — Execution plan](#part-3--execution-plan)**: an ordered, gated sequence to run.

**Companion documents.** [`DEMO_WALKTHROUGH.md`](DEMO_WALKTHROUGH.md) is the ~90-minute functional
pass over a purpose-built demo vault — it stays the *how do I prove each feature works* document,
and it is Phase 5 of the plan below. This document is the submission wrapper around it:
listing truth, store configuration, and the go/no-go. [`gloss#50`](https://github.com/michaelcraiggroup/gloss/issues/50)
is the issue tracking that pass.

**Everything below was verified against source on 2026-08-05** at commit `11c73d7` (branch
`feat/sidebar-hierarchy-graph-off-1.23.0`, PR [#72](https://github.com/michaelcraiggroup/gloss/pull/72)).
Evidence commands are in the [appendix](#appendix--evidence-log).

---

## Part 1 — Feature-by-feature evaluation

**Legend**

| Mark | Meaning |
| :--: | --- |
| ✅ | Ships, and the listing describes it accurately |
| 🆓 | Ships free, listing accurate |
| ⚠️ | Ships, but the listing is silent or imprecise about it |
| ❌ | The listing claims it and the build does not support it as claimed |
| 🚫 | Shelved — not in the build, must not be in the copy |

### Reading core (free tier)

| Feature | Where it lives | Listing | Verdict |
| --- | --- | :--: | :--: |
| Rendered markdown reading (swift-markdown → HTML → WKWebView) | `GlossKit/MarkdownRenderer.swift` | claimed | 🆓 |
| Syntax highlighting | `MarkdownRenderer.swift:568` — hljs 11.9.0 from cdnjs | **"180+ languages"** | ❌ **B4** |
| Mermaid diagrams | `MarkdownRenderer.swift:631` — mermaid 11.12.0, loaded only when a diagram is present | claimed | ⚠️ **B10** |
| KaTeX math | `MarkdownRenderer.swift:656` — KaTeX 0.16.9, loaded only when math is present | claimed | ⚠️ **B10** |
| Dark/light themes following the system | `gloss-theme.css` + `Color+Gloss.swift` | claimed | 🆓 |
| Live reload | `Services/FileWatcher.swift` | claimed | 🆓 |
| Vim-style keys (j/k/gg/G/Space) | injected JS in `MarkdownRenderer` | claimed | 🆓 |
| Copy-code buttons | injected JS | claimed | 🆓 |
| Heading anchors | heading-ID post-processing | claimed | 🆓 |
| Find in page (⌘F / ⌘G / ⇧⌘G) | `GlossApp.swift:309-323` | claimed (⌘F only) | 🆓 |
| Print + PDF export (⌘P / ⌘E) | `GlossApp.swift:224-282`, offscreen `createPDF` | claimed | 🆓 |
| Document zoom (⌘= / ⌘− / ⌘0) | `GlossApp.swift:362-384`, `AppSettings.pageZoom` | **absent** | ⚠️ **B8** |
| Zen mode (⌃⌘Z) | `GlossApp.swift:340-346` | **absent** | ⚠️ **B8** |
| Open in external editor | `Services/EditorLauncher.swift` | claimed | 🆓 |

### Editing (free tier)

| Feature | Where it lives | Listing | Verdict |
| --- | --- | :--: | :--: |
| Live-preview editor (⇧⌘E), CodeMirror 6 | `Components/EditorWebView.swift`, `Resources/editor.html` | claimed | 🆓 |
| CM6 bundled locally (works offline) | `Resources/codemirror-bundle.js`, 580 KB | n/a | ✅ |
| Save (⌘S) + auto-save on mode switch | `EditorWebView` bridge | implied | 🆓 |
| New file (⌘N), rename, delete (sidebar context menus) | `Models/FileTreeModel.swift` | **absent** | ⚠️ |

### Vault, navigation, knowledgebase (Pro tier)

| Feature | Gate | Listing | Verdict |
| --- | --- | :--: | :--: |
| Folder sidebar / file tree | `.folderSidebar` | claimed | ✅ |
| Inspector — TOC, frontmatter, tags, backlinks, unlinked mentions | `.inspector` | TOC + frontmatter + backlinks claimed; **unlinked mentions absent** | ⚠️ |
| Editable frontmatter properties | `.inspector` | listing says "display" only | ⚠️ **B8** |
| Wiki-link navigation, incl. 8 typed relations | `.wikiLinks` | claimed (untyped) | ⚠️ |
| Full-text search (FTS5) + tag/type filter chips | `.fullTextSearch` | claimed | ✅ |
| Favorites & recents, vault-scoped | `.favorites` | claimed | ✅ |
| Font size control | `.fontSizeControl` | claimed | ✅ |
| Tags + tag filtering | (needs a vault) | **absent** | ⚠️ **B8** |
| Transclusion `![[note#heading]]` | (needs a vault) | **absent** | ⚠️ **B8** |
| md+ queries (`type: query` blocks) | (needs a vault) | **absent** | ⚠️ **B8** |
| Fillable templates + Save Filled Copy… | `TemplateFillService` | **absent** | ⚠️ **B8** |
| Daily notes (⌘T) | vault gate only | **absent** | ⚠️ **B8** |
| Quick Capture (menu-bar bolt + hot corner) | ungated | **absent** | ⚠️ **B8 / B12** |
| Vault overview dashboard | ungated (needs a vault) | **absent** | ⚠️ |
| **Vault graph** | — | **removed from copy 2026-08-05** | 🚫 |

### System integration

| Feature | Where it lives | Listing | Verdict |
| --- | --- | :--: | :--: |
| Quick Look extension | `GlossQLExtension/`, embedded target | claimed | ✅ (flaky — see quirk note) |
| `gloss` CLI installer | `GlossApp.swift:595` — copies a `sudo ln -sf` command, app never writes outside the sandbox | **absent** | ⚠️ **B13** |
| Finder document types (.md, .markdown, folders) | `Scripts/Info.plist` | implied | ✅ |
| Security-scoped bookmarks (vault survives relaunch) | `Services/SecurityScopedBookmarks.swift` | n/a | ✅ |
| Guided walkthroughs (Help menu) | `GlossGuideService` + Rabble Guide SDK | **absent** | ⚠️ |

### Monetization

| Item | Value | Verdict |
| --- | --- | :--: |
| Product ID | `group.michaelcraig.gloss.full` | ✅ |
| Type / price / sharing | Non-consumable, $9.99, Family Sharing | ✅ |
| App Store Connect display name | "Gloss Pro" | ⚠️ **B6** — not yet created in the Console |
| Gated features in code | 6 reachable: sidebar, inspector, search, favorites, wiki-links, font size (`PaidFeature.graphView` remains in the enum but is unreachable) | ✅ |
| Offline unlock cache | `UnlockCachePolicy` + `lastVerifiedUnlockAt` | ⚠️ **B9** — never validated on a fresh machine |
| Restore Purchase + honest failure states | `StoreManager` + `PaywallView` | ✅ |

### The two lists that matter

**Claims the build does not support as written**

1. "Syntax highlighting for 180+ languages" — the build loads cdnjs's `highlight.min.js`, which is
   the core + *common* bundle, not the full language set. → **B4**

**Shipped features the listing never mentions** (each one is a reason someone would buy):
quick capture, daily notes, transclusion, md+ queries, fillable templates, tags and tag filtering,
document zoom, zen mode, editable frontmatter, unlinked mentions, the vault dashboard, guided
walkthroughs, and the CLI. → **B8**

---

## Part 2 — Blocker board

Hard blockers (H) must be resolved before submission. Medium (M) should be. Low (L) is a judgment
call you can defer with eyes open.

| # | Sev | Blocker | Evidence | Fix | Est. |
| --- | :--: | --- | --- | --- | --- |
| **B1** | H | **Privacy Policy URL 404s** | `curl -L https://michaelcraig.group/privacy` → `404` | Publish the page (goose repo). App Store Connect will not accept a version without a working privacy URL. | 1–2h |
| **B2** | H | **Support URL 404s** | `curl -L https://michaelcraig.group/support` → `404` | Publish a support page with a contact route. (Marketing URL `/products/gloss` → `200`, fine.) | 1h |
| **B3** | H | **`LSApplicationCategoryType` missing** | `Scripts/Info.plist` has no such key; built 1.21.3 bundle confirms | Add `public.app-category.developer-tools` to `project.yml` → regenerate. Mac App Store requires it. | 10m |
| **B4** | H | **"180+ languages" is false as built** | `MarkdownRenderer.swift:568` loads cdnjs `highlight.min.js` (core+common) | Either bundle the full hljs build locally (also fixes B10 partly) **or** soften the copy to "40+ common languages". *Litmus:* render an Ada block — if it isn't highlighted, the claim is false. | 30m–3h |
| **B5** | H | **No Mac App Store build path** | `Scripts/release-dmg.sh` is Developer ID + `notarytool` only; no `-exportOptionsPlist` with an App Store method | Add a MAS archive/export/upload path (Xcode Organizer is fine for release one; script it after). Needs the Mac App Distribution cert + provisioning profiles for **both** targets (app + QL extension). | 1–2h |
| **B6** | H | **IAP not configured in App Store Connect** | Only the local `GlossStore.storekit` config exists | Create the non-consumable (`group.michaelcraig.gloss.full`, "Gloss Pro", $9.99, Family Sharing), fill its review screenshot + notes, and **attach it to the first version** — first-release IAPs are reviewed with the app. | 1h |
| **B7** | H | **No screenshots captured** | No screenshots directory in the repo | Capture the five planned shots (markers are in `DEMO_WALKTHROUGH.md`). At least one is required; five is the plan. | 1h |
| **B8** | H | **Listing copy is stale in both directions** | See the two lists above | Rewrite the description + What's New for 1.23: drop the graph (done in-repo), add capture/daily notes/queries/transclusion/tags/zoom. Bump "What's New (v1.20)" → v1.23. | 1–2h |
| **B9** | H | **No signed build has passed a full verification pass** | [#50](https://github.com/michaelcraiggroup/gloss/issues/50) open since 2026-07-07 | Run `DEMO_WALKTHROUGH.md` end to end on a **signed** build. SPM builds hardcode `isUnlocked = true` and have no StoreKit and no Quick Look — the paywall, purchase, unlock cache, and QL can only be proven from the signed app. | 3h |
| **B10** | M | **Rendering libraries load from a CDN** | hljs, mermaid, KaTeX from `cdnjs.cloudflare.com`; `com.apple.security.network.client` entitlement | Two exposures: (a) reviewers commonly test offline — code blocks lose highlighting and diagrams/math don't render; (b) "never phones home" sits awkwardly next to a third-party request that reveals the user's IP. Bundle them locally (best), or state the behavior plainly in the description and App Review notes. | 2–6h |
| **B11** | M | **Build-number policy** | `Scripts/Info.plist` `CFBundleVersion` = `1` while `project.yml` `CURRENT_PROJECT_VERSION` = `12`; see [#25](https://github.com/michaelcraiggroup/gloss/issues/25) | Decide the number that ships and make the two agree. Every App Store Connect upload needs a **higher** build number than the last — a repeat is rejected at upload. | 30m |
| **B12** | M | **Quick Capture hot corner defaults ON** | `QuickCaptureController` + settings default | A panel that appears when the pointer hits a screen corner will surprise a reviewer who didn't ask for it. Either default it off, or disclose it in the review notes (`DEMO_WALKTHROUGH.md` already drafts that text). | 15m |
| **B13** | L | **CLI installer instructs a `sudo` command** | `GlossApp.swift:595-643` | The app itself never writes outside the sandbox (it copies a command to the clipboard), which is the sandbox-safe design. Low rejection risk, non-zero. Keep it, and mention it in review notes. | 10m |
| **B14** | L | **`xcodebuild test` is broken** | [#36](https://github.com/michaelcraiggroup/gloss/issues/36) — Yams link failure in the TEST_HOST path | Doesn't block submission (`swift test` is canonical and green at 385 tests), but it means the Xcode scheme you archive from can't self-verify. | 1–2h |
| **B15** | L | **Export-compliance + copyright keys absent** | `Scripts/Info.plist` | Add `ITSAppUsesNonExemptEncryption = false` (HTTPS-only use is exempt) so you don't answer it per upload, and `NSHumanReadableCopyright`. | 10m |
| **B16** | L | **Universal Purchase not decided** | [#68](https://github.com/michaelcraiggroup/gloss/issues/68), `PROJECT_PLAN.md` open questions | Decide *before* the first iOS TestFlight, not before this submission. Noted here so it isn't discovered late. | — |

**Not blockers, confirmed good:** app sandbox on with the right entitlements (user-selected R/W,
app-scope bookmarks, network client, print); 1024 px app icon; macOS 14.0 deployment target;
Swift 6; StoreKit 2 with honest restore/failure states; privacy *manifests* aren't required for
macOS submissions (that rule covers iOS/iPadOS/tvOS/watchOS/visionOS) — the App Store Connect
privacy **nutrition label** is what you fill in, and "Data Not Collected" is accurate.

---

## Part 3 — Execution plan

Each phase ends in a gate. Don't start the next phase until the gate is true.

### Phase 0 — Decisions only you can make (~30 min)

- [ ] **B4 language claim.** Bundle full hljs, or soften the copy? (Run the Ada litmus first — it
      takes two minutes and settles the argument.)
- [ ] **B10 CDN.** Bundle hljs/mermaid/KaTeX locally for 1.23, or ship as-is with disclosure?
      Bundling also makes the app work on a plane, which is a selling point, not just a fix.
- [ ] **B8 listing scope.** Minimal correction (remove the graph, fix the language claim) or the
      full refresh that finally sells capture, daily notes, and queries?
- [ ] **B12 hot corner.** Default off for the App Store build, or keep and disclose?
- [ ] **B11 build number.** What ships as `CFBundleVersion` for upload #1?

**Gate:** five answers written down.

### Phase 1 — Repo fixes (~2–3h, less if you defer B10)

- [ ] Merge PR [#72](https://github.com/michaelcraiggroup/gloss/pull/72) (sidebar hierarchy + graph shelved) after the manual QA in its checklist.
- [ ] **B3** `LSApplicationCategoryType: public.app-category.developer-tools` in `project.yml`.
- [ ] **B15** `ITSAppUsesNonExemptEncryption = false`, `NSHumanReadableCopyright`.
- [ ] **B11** reconcile `CFBundleVersion` / `CURRENT_PROJECT_VERSION`; close [#25](https://github.com/michaelcraiggroup/gloss/issues/25).
- [ ] **B4** apply the decision (bundle or copy change).
- [ ] **B10** if bundling: vendor hljs + mermaid + KaTeX into `GlossKit/Resources`, mirroring how
      `codemirror-bundle.js` is already handled; delete the CDN `<script>`/`<link>` tags.
- [ ] **B12** apply the hot-corner decision.
- [ ] Version bump + `CHANGELOG.md` entry; regenerate with `xcodegen`, restoring
      `Scripts/Info.plist`'s version by hand afterwards (it gets clobbered — see the note in
      `project.yml`).
- [ ] `swift test` green.

**Gate:** `swift test` green, `xcodegen generate` clean, PR merged.

### Phase 2 — Website (goose repo) (~2h)

- [ ] **B1** publish `https://michaelcraig.group/privacy` — must state plainly: no collection, no
      telemetry, no accounts, and (if you didn't bundle) that rendering libraries are fetched from
      Cloudflare's CDN.
- [ ] **B2** publish `https://michaelcraig.group/support` with a working contact route.
- [ ] Re-check all three URLs return 200.

**Gate:** `curl -s -o /dev/null -w "%{http_code}" -L <url>` returns `200` for privacy, support, and
marketing.

### Phase 3 — Build the App Store artifact (~1–2h)

- [ ] Signing: Mac App Distribution certificate; provisioning profiles for **both**
      `group.michaelcraig.gloss` and `group.michaelcraig.gloss.quicklook`.
- [ ] Archive Release from `Gloss.xcodeproj`, export with an App Store method (Organizer for this
      first one), upload to App Store Connect.
- [ ] Confirm the uploaded build shows the expected version **and** that the QL extension is
      embedded in it.
- [ ] Also build the signed Developer ID DMG (`Scripts/release-dmg.sh`) — that's what Phase 5 tests.

**Gate:** build processed in App Store Connect without an email full of validation warnings.

### Phase 4 — App Store Connect configuration (~1h)

- [ ] **B6** create the IAP: `group.michaelcraig.gloss.full`, Non-Consumable, "Gloss Pro", $9.99,
      Family Sharing on; add its review screenshot + notes; **attach it to version 1.23**.
- [ ] **B8** paste the corrected description, keywords, promo text, and a 1.23 "What's New".
- [ ] Privacy nutrition label → **Data Not Collected**.
- [ ] Category: Developer Tools (primary), Productivity (secondary). Age rating. Content rights.
- [ ] Review notes — say the quiet parts out loud: how to unlock Pro for review, the CDN behavior
      (if unbundled), the hot corner (if kept), and the optional CLI installer.

**Gate:** every required field green in App Store Connect except screenshots.

### Phase 5 — Verification pass (~3–4h) — the real gate

Run against the **signed DMG build**, on a Mac that has never run Gloss if you can manage it.
Never against `swift run`.

- [ ] Full `DEMO_WALKTHROUGH.md` pass, top to bottom, capturing 📸 markers as you go (this also
      produces Phase 6's screenshots). Closes [#50](https://github.com/michaelcraiggroup/gloss/issues/50).
- [ ] **Purchase path:** sandbox Apple Account → paywall → purchase → features unlock.
- [ ] **Unlock cache** ([#38](https://github.com/michaelcraiggroup/gloss/issues/38)): fresh install → Restore Purchase seeds `lastVerifiedUnlockAt`;
      relaunch restores the vault at first frame; relaunch **offline** stays unlocked.
- [ ] **Offline pass:** turn off Wi-Fi and open a document with code, a Mermaid diagram, and math.
      Record exactly what degrades — a reviewer may see precisely this.
- [ ] **Sandbox pass:** open a vault, quit, relaunch → vault restores without a Grant Access prompt.
- [ ] **Quick Look:** spacebar on a `.md` in Finder renders through Gloss (if macOS falls back to
      its text handler, `qlmanage -r` and relaunch Finder before concluding anything).
- [ ] **Graph is gone:** View menu has no "Show Vault Graph"; ⌥⌘G does nothing; sidebar toolbar
      shows Refresh + Open Vault only; the paywall lists six features.
- [ ] **Sidebar hierarchy** (new in 1.23): vault card reads as primary in light *and* dark; shelves
      recede; selection highlight still visible everywhere.
- [ ] Every remaining claim in the `DEMO_WALKTHROUGH.md` ledger ticked or struck.

**Gate:** no ❌ in the ledger, and no crash, hang, or Grant Access dead-end in the whole pass.

### Phase 6 — Screenshots (~1h)

- [ ] Five shots at 2560×1600 from the demo vault: hero (sidebar + rendered doc, dark), inspector,
      wiki-links, Quick Look in Finder, light theme.
- [ ] Nothing in frame contradicts the listing — no graph, no personal file names, no placeholder
      text.

**Gate:** uploaded, and each one shows a feature the description actually claims.

### Phase 7 — Submit

- [ ] Re-read the description against Part 1 one last time.
- [ ] Submit for review with the IAP attached.
- [ ] Tag the release and archive the artifacts per the deployment-evidence convention.

---

## Go / No-Go sign-off

Submit only when every line is true.

| # | Condition | Signed |
| --- | --- | :--: |
| 1 | No ❌ rows remain in Part 1 | ☐ |
| 2 | B1–B9 all resolved | ☐ |
| 3 | B10–B12 resolved **or** explicitly disclosed in review notes | ☐ |
| 4 | Full `DEMO_WALKTHROUGH.md` pass on a signed build, no blockers found | ☐ |
| 5 | Purchase + restore + offline-relaunch verified in sandbox | ☐ |
| 6 | Privacy, support, and marketing URLs all return 200 | ☐ |
| 7 | Screenshots match shipped behavior | ☐ |
| 8 | Description reviewed line by line against Part 1 | ☐ |

---

## Appendix — evidence log

Run 2026-08-05 at commit `11c73d7`, working directory `~/Projects/gloss` on the dev Mac.

| Check | Command | Result |
| --- | --- | --- |
| Tests | `cd macos && swift test` | 385 tests / 45 suites passed |
| Listing URLs | `curl -s -o /dev/null -w "%{http_code}" -L <url>` | privacy **404**, support **404**, products/gloss **200** |
| Category key | `PlistBuddy -c "Print :LSApplicationCategoryType" .release/dmg-src/Gloss.app/Contents/Info.plist` | *Does Not Exist* |
| Build number | same bundle, `:CFBundleVersion` | `1` (vs `CURRENT_PROJECT_VERSION: "12"`) |
| CDN deps | `grep -rn cdnjs Sources/GlossKit` | hljs 11.9.0 (js + 2 css), mermaid 11.12.0, KaTeX 0.16.9 |
| CM6 | `ls Sources/Gloss/Resources/codemirror-bundle.js` | 580 KB, bundled locally |
| Paid gates | `grep -rn "store.gate(" Sources/Gloss` | 6 reachable features + shelved `.graphView` |
| Release path | `grep -n "notarytool\|exportOptions" Scripts/release-dmg.sh` | Developer ID + notarization only |
| Entitlements | `macos/project.yml` | sandbox, user-selected R/W, app-scope bookmarks, network client, print |

Re-run these before submitting — they're cheap, and three of them are the difference between a
clean review and a rejection.

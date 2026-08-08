# iOS + Vault Sync — Two-Device QA Script

> The arc-closing manual pass for the iOS companion + vault sync arc
> (plan: `mcg-operations/plans/gloss/2026-08-08-ios-companion-vault-sync.md`,
> issues #76–#79). **Run it twice**: once on a fresh pairing (iPhone that has
> never run Gloss) and once dirty (app already installed, a different vault
> open). Every step lists the expected result — a miss is a bug, not a QA
> judgment call.
>
> **Builds**: Mac = signed build (`Scripts/release-dmg.sh` output or ⌘R —
> never `swift run`: SPM builds are unsigned, so no sandbox, no StoreKit, no
> iCloud). iPhone = ⌘R from `Gloss.xcodeproj`, scheme **GlossiOS** (uses
> `GlossStore.storekit` for purchase testing). Both devices signed into the
> **same Apple Account** with iCloud Drive on.

## 0 — Preflight

- [ ] `swift test` green; `xcodegen generate` clean.
- [ ] Mac: Finder → iCloud Drive shows a **Gloss** folder (created by the
      first signed launch — see `docs/ICLOUD_SETUP.md` if missing).
- [ ] iPhone: Settings → [your name] shows the same Apple Account.

## 1 — Move a vault to iCloud (Mac)

Use a disposable copy of a real vault (favorites set, wiki-links present).

- [ ] Open the local vault → File → **Move Vault to iCloud…** — the sheet
      explains the move; **Move to iCloud** runs without errors.
- [ ] The vault **reopens automatically from the container**
      (`iCloud Drive → Gloss → <name>`); sidebar, favorites, recents, and
      backlinks all intact.
- [ ] `.gloss/` inside the moved vault contains **favorites.json only** — no
      `index.sqlite` (the index now lives in
      `~/Library/Application Support/Gloss/VaultIndexes/<name>-<hash>/`).
- [ ] File → **Set Up iPhone…** — QR renders; the upload line progresses to
      "Vault is uploaded to iCloud".
- [ ] **Crash drill**: repeat with a second disposable vault and force-quit
      Gloss mid-move → relaunch → the journal heals (the vault is wherever it
      actually landed; `rootFolderPath` matches; nothing lost).

## 2 — Pair the iPhone

- [ ] **Camera doorway**: point the iPhone Camera app at the Mac's QR → the
      Gloss banner opens the app → "Looking for …" (briefly) → the vault
      opens with the Mac's appearance + font size applied.
- [ ] **In-app doorway** (reset: delete the app, reinstall): vault list →
      **Pair with Mac…** → live scanner → same result.
- [ ] **Auto-discovery** (reset again): don't scan at all — the vault appears
      in the list by itself; tapping it opens it.
- [ ] **Foreign QR**: scan any random QR in the wild → "Not a Gloss pairing
      code" + Try Again (no crash, no half-state).
- [ ] **Wrong-account copy**: if a second Apple Account is available, sign
      the iPhone into it and scan → the locating screen persists and after
      ~30s advises checking the Apple Account — and **keeps listening**
      (no terminal failure).
- [ ] **Pro gate**: with the StoreKit-config build and Pro locked, scanning
      fires the paywall; completing the (sandbox) purchase **resumes the
      pairing automatically**.

## 3 — Read + sync (both devices)

- [ ] iPhone: tree renders; markdown downloads eagerly (badges/placeholder
      states clear on their own); a note with code, Mermaid, KaTeX, and
      wiki-links renders with the amber theme.
- [ ] Wiki-link tap navigates; Back/Forward track history; the inspector
      sheet shows TOC / tags / forward links / backlinks; TOC tap scrolls.
- [ ] Search: filename hits; content hits with snippets; opening a content
      hit highlights matches in the reader. Content scope while locked
      bounces to Filenames + paywall.
- [ ] **Live update Mac → iPhone**: edit a note on the Mac → the iPhone
      reader refreshes within seconds (no relaunch).
- [ ] **Favorites both ways**: favorite a note on the Mac → it appears on
      the iPhone's shelf; unfavorite on the iPhone → it leaves the Mac's.
      (Two-writer merge: neither device's change clobbers the other.)
- [ ] **Evicted-file states**: on the iPhone, open a note that hasn't
      downloaded → "Downloading from iCloud" → renders when it lands. On the
      Mac, evict a file (Remove Download in Finder) and open it → same
      state, self-heals.

## 4 — Offline drills

- [ ] iPhone airplane mode → previously-downloaded notes read normally;
      never-downloaded notes show the downloading state (and land after
      airplane mode ends).
- [ ] Mac offline → container vault opens from the local replica; edits
      made offline sync to the iPhone once back online.

## 5 — Dirty-account second pass

Repeat §§1–3 with the app already installed, another vault open, and Pro
already unlocked. Watch specifically for: pairing replacing the open vault
cleanly, recents/favorites keeping their per-vault buckets, and no duplicate
vault rows in the list.

## Sign-off

| Check | Pass 1 (fresh) | Pass 2 (dirty) |
| --- | :--: | :--: |
| §1 Move + crash drill | ☐ | ☐ |
| §2 All six pairing drills | ☐ | ☐ |
| §3 Read + sync + favorites + evicted | ☐ | ☐ |
| §4 Offline | ☐ | ☐ |

Both columns clean twice = the arc's exit gate (#79) and the go signal for
TestFlight (remember: iOS platform joins the **existing** App Store Connect
record — Universal Purchase).

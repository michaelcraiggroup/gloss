# TestFlight — GlossiOS

> The ship channel for the iOS companion, opened by the QA double-pass
> (`docs/IOS_QA_SCRIPT.md`, gate passed 2026-08-09, closing #79/#68).

## The one unforgiving rule

**The iOS platform joins the EXISTING App Store Connect app record for
`group.michaelcraig.gloss` — never a new record.** Universal Purchase (one
$9.99 unlock covering Mac + iPhone) exists only while both platforms share
the record. A separate iOS record forfeits it permanently; there is no
migration path back.

## Console steps (one-time, Michael)

Do these in order at appstoreconnect.apple.com:

1. **Add the iOS platform** to the existing Gloss app record: App Store →
   Gloss → the platform "+" (App Information / left rail) → iOS. If the UI
   instead offers "New App", STOP — that creates a second record. The iOS
   platform must appear inside the existing app's page.
2. **Create the in-app purchase** (it has never existed in the Console —
   flagged in the 2026-08-05 readiness review):
   - Type: Non-Consumable
   - Product ID: `group.michaelcraig.gloss.full` (must match `PaidFeature`'s
     StoreKit id exactly — source of truth in `StoreManager`)
   - Reference name: Gloss Pro; price: $9.99 (Tier where applicable)
   - A screenshot + review notes are required before App Review, but NOT
     for internal TestFlight testing.
3. **TestFlight → Internal Testing**: create a group ("Gloss"), add your
   Apple Account as tester. Internal builds need no beta review and appear
   minutes after processing.
4. Nothing else is required for internal TestFlight. (App Privacy answers —
   "Data Not Collected" — and the full metadata are App Review concerns,
   tracked in #74 alongside the Mac App Store blockers.)

## First archive (GUI, one time)

The first App Store archive should go through Xcode so it can mint the
Apple Distribution certificate and App Store provisioning profile (the
repo's headless builds only hold Developer ID + development assets):

1. `cd macos && xcodegen generate && open Gloss.xcodeproj`
2. Scheme **GlossiOS**, destination **Any iOS Device (arm64)**
3. Product → Archive → Organizer opens → **Distribute App** →
   **TestFlight & App Store** → defaults through → Upload. Approve any
   certificate/profile prompts — that's the minting.

After this one run, the headless script works for every future build.

## Every build after (headless)

```bash
cd /Users/michael/Projects/gloss/macos
Scripts/testflight-archive.sh --build <N> --upload
```

- `--build N` — the App Store Connect build number for THIS upload. Repo
  files never change (`CURRENT_PROJECT_VERSION` stays untouched per repo
  convention); the script passes the number as a build-setting override.
  Apple requires each upload's number to be unique for the version — take
  the next integer from the ledger below.
- Omit `--upload` to get an `.ipa` in `macos/.release/testflight/` for
  Transporter.app instead.
- The script preflights the privacy manifest, icon, and marketing version,
  and post-checks the archive (build number applied, iCloud entitlement
  present, manifest embedded) before exporting.

## Testing the build on TestFlight

- **Purchases are sandbox** — the TestFlight build talks to the sandbox
  App Store. Buying Gloss Pro prompts with the signed-in Apple Account and
  charges nothing. The QA-era device builds used the local StoreKit config;
  TestFlight is the first REAL StoreKit exercise of the Universal Purchase
  product — verify: paywall shows $9.99 → purchase succeeds → relaunch
  stays unlocked → "Restore Purchase" works.
- Vault sync is the production iCloud container — the QA vaults
  (GlossQA-Alpha…Delta) will appear if still in iCloud Drive → Gloss.
- The Mac side needs no TestFlight: the signed Mac app already ships via
  the Developer ID DMG (`Scripts/release-dmg.sh`).

## Build ledger

| Build | Marketing | Date | Notes |
| --- | --- | --- | --- |
| _(next: 13)_ | 1.27.1 | — | first TestFlight upload |

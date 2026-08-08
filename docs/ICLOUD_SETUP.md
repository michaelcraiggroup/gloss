# iCloud Setup — container, App ID, profiles

> Record of the manual Apple-portal state the vault-sync arc depends on
> (plan: `mcg-operations/plans/gloss/2026-08-08-ios-companion-vault-sync.md`,
> milestone issue [#77](https://github.com/michaelcraiggroup/gloss/issues/77)).
> Everything here is done once per team, not per release.

## The one container

| Item | Value |
| --- | --- |
| Container ID | `iCloud.group.michaelcraig.gloss` |
| Service | CloudDocuments (no CloudKit) |
| User-visible name | **Gloss** (iCloud Drive folder, via `NSUbiquitousContainers`) |
| Local replica (macOS) | `~/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/` |
| Vaults live under | `<container>/Documents/<Vault Name>/` |

**One-way latch:** `NSUbiquitousContainers` values (`IsDocumentScopePublic: true`,
name "Gloss", folder levels `Any`) only take effect with a `CFBundleVersion`
bump, and un-publishing a public container is unreliable. Treat them as
permanent — they are declared in `macos/project.yml` and must never change.

## Portal state (done 2026-08-08, by Michael)

1. ✅ **iCloud container created** — Identifiers → iCloud Containers →
   `iCloud.group.michaelcraig.gloss`.
2. ✅ **App ID registered** — explicit `group.michaelcraig.gloss` (the Mac app
   never needed a portal App ID before: Developer ID with no restricted
   entitlements requires neither an App ID record nor a profile — iCloud is
   what changed that). iCloud capability enabled, container assigned.
   The QL extension's `group.michaelcraig.gloss.quicklook` deliberately has
   **no** App ID / profile until the Mac App Store path (readiness B5).

## Remaining one-time steps

3. ✅ **Developer ID provisioning profile** — `Gloss Developer ID iCloud`
   installed 2026-08-08 (gotcha for posterity: **double-clicking a
   downloaded `.provisionprofile` does not install it** — copy it by UUID
   into `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`).
   `Scripts/release-dmg.sh` preflights for it by name; the full notarized
   DMG gate passed the same day (evidence on PR #83).
4. ✅ **Development signing for ⌘R** — Xcode auto-minted the Mac team
   provisioning profile when the App ID gained the iCloud capability.
5. ☐ Later, before the first iOS TestFlight: add the **iOS platform to the
   existing App Store Connect record** (same bundle id — Universal Purchase).
   Never create a second app record; that forfeits Universal Purchase
   permanently.

## How signing works now (macOS)

- **Debug**: `CODE_SIGN_STYLE: Automatic` (project.yml base) — Xcode manages
  a development profile for the iCloud entitlement.
- **Release (Developer ID)**: per-target manual signing in `project.yml`:
  the app embeds `Gloss Developer ID iCloud`; the QL appex signs
  profile-free (no restricted entitlements). `release-dmg.sh` no longer
  passes signing overrides on the command line — CLI settings apply to every
  target, and the appex can't use the app's profile.
- Notarization/stapling flow is unchanged and fully compatible with the
  embedded profile.

## Behavior notes

- SPM builds (`swift run`) are unsigned → no entitlements → container
  resolution returns nil → all iCloud features degrade to "unavailable".
  Container behavior is only testable in signed Xcode builds.
- `UbiquityVaultStore` is the single resolution point
  (`url(forUbiquityContainerIdentifier:)` off-main, per Apple's requirement);
  `UbiquityVaultStore.isUbiquitousPath(_:)` is the stateless "is this inside
  the container?" test used by bookmark no-ops and restore deferral.

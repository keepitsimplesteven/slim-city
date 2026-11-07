# Slim City — Inbox

Central braindump for features, bugs, and ideas. Jot anything here, freeform.
This is an INBOX, not a Crew spec — don't point `kirocrew run` at this file.

## Handoff pipeline
When something under **Ready to hand off** is ready to build:
- Ask Kiro: "spec out <item>" → generates a scoped `specs/<name>.md` in Crew's
  format (pinned to the frozen APIs + build notes), then `kirocrew run specs/<name>.md`.
- Or in the Crew dashboard: Compose + ✨ Refine, then Run. If you go this route,
  paste `specs/_crew-preamble.md` into the Compose box first — steering guards
  execution, but it does NOT shape the Refine step (Refine is a single-shot call).
Either way, `.kiro/steering/slim-city-constraints.md` enforces the project
guardrails on every Crew task step. Check items off here once verified.

---

## Ready to hand off (fair game for Crew)
- [x] **Debug mode (in-app debug menu).** DONE on the `debug` branch. A
  developer-only overlay for testing the economy/claim loop without walking
  around. All actions go through the frozen public APIs — pure UI + view-model
  intents, no new game rules, no core/persistence API changes. Everything is
  `#if DEBUG`, so release builds are untouched.

  **Entry point.** `ladybug.fill` button pinned top-trailing in `CityScreen`
  (below the `WalletHUD`), presenting a `DebugPanel` sheet. See
  `SlimCity/SlimCity/CityScreen.swift` (button + sheet) and
  `SlimCity/SlimCity/Debug/DebugPanel.swift` (panel UI).

  **Actions (shipped):**
  - [x] **Add X of Y resource.** Picker + stepper + "Add". Credits the wallet
    via `CityViewModel.debugCredit(_ type:, amount:)`, which calls
    `GameState.credit(_:)` and forwards through `onStateChanged` (same persist
    path `place(...)` uses). Non-positive amounts are a no-op.
  - [x] **Reset all.** Confirmation dialog → `AppContainer.debugReset()`:
    `CityViewModel.debugReset()` swaps in a fresh `GameState` (default grid +
    starting wallet, cleared buildings/selection) and
    `DebugActions.resetPersistedState()` persists a fresh state and clears the
    ledger. Also zeroes `claimableDays` / `lastClaim` so the HUD isn't stale.
  - [x] **Simulate X days.** Source toggle (prev-day / 7-day avg) + day stepper
    + "Simulate" → `AppContainer.debugSimulate(days:source:)` →
    `DebugActions.simulateDays(...)`. Takes the CLAIM PATH: writes synthetic
    unclaimed `DailyLedgerEntry` rows for the most recent days and runs the real
    `LedgerService.claim`, so dedupe + the backfill cap are exercised.

  **Resolved (were open questions):**
  - Economy source of truth: **`BalanceConfig.default`** — that's what the live
    claim loop resolves rates + backfill cap from, so debug grants == real
    grants.
  - Backfill cap: **respected** (the "more honest" option). `simulateDays`
    clamps the filled days to the claim window; a sim can't out-run what the
    real loop could deliver.
  - Reset resets `AppContainer.claimableDays` / `lastClaim` — done.
  - All actions are idempotent-safe to spam (already-claimed days aren't
    re-granted; non-positive credits no-op).

  **Known gap (frozen-API limit, NOT fixed here):** the `LedgerStore` /
  `PersistenceController` surface has upsert + load but **no row delete**, so
  "Reset all" can't physically empty the ledger table — it neutralizes every row
  (zero metrics, unclaimed) instead. A truly empty table needs a new persistence
  API; left as-is per the no-API-change rule.

  **Verification:** pure logic (VM debug intents + `DebugActions`) unit-tested
  in `SlimCityAppLogic` (15 new tests, all green via
  `SlimCityCore/scripts/test.sh`-style `swift test --disable-sandbox`).
  `DebugActions.swift` is symlinked into the AppLogic harness like the other
  app-layer logic. The SwiftUI entry point + panel (`CityScreen`, `DebugPanel`)
  are Xcode-only and were NOT built headlessly — verify the button/sheet in a
  simulator.

- [ ] **Pannable / zoomable map.** The isometric SceneKit camera is currently
  fixed (orthographic, look-at the grid center). Add pan to move the view and
  pinch/scroll to zoom. Likely a pan + pinch gesture on the `SCNView` in
  `CitySceneView` driving the camera node. Must not fight the tap-to-place
  gesture. Keep the isometric look (don't free-rotate).

## Deferred — designed-for, DON'T build yet (seams already in place)
- [ ] **Passive / idle production.** `BuildingDefinition.production` field exists
  (unused). Wire a tick system to credit production over time.
- [ ] **CloudKit sync.** Models are CloudKit-shaped; flip is one line in
  `PersistenceController` (`cloudKitDatabase: .none → .automatic`) + the
  entitlement. See `SlimCity/ARCHITECTURE_SEAMS.md`.
- [ ] **Anti-cheat enforcement.** `AntiCheatPolicy` is pass-through; enable
  value caps / discard-user-entered when it matters.
- [ ] **Real art for farm & market.** Drop `farm.usdz` / `market.usdz` into the
  app bundle — pure asset swap, no code change (`house.usdz` already proves the
  path; farm/market currently render as colored-box placeholders).

## Chores — manual, NOT for Crew
- [ ] **Reconnect the watch app to the iOS app** (embed phase + target
  dependency) once an Apple Developer account / signing is sorted. Currently
  decoupled so the iOS app builds without a team. Watch code is done and builds
  standalone. `WKCompanionAppBundleIdentifier` already matches. (Xcode UI task.)
- [ ] **No macOS render path.** `CitySceneView` is UIKit-only; on a Mac build
  the center falls back to a gray placeholder. Add an AppKit
  (`NSViewRepresentable`) branch only if we ever want it on macOS. Run on an
  iPhone simulator for now.
- [ ] **Template leftover:** iOS target `productName` is still `MyApp` and the
  entry file is `MyApp.swift`. Cosmetic; rename when convenient.
- [ ] **Re-enable the command sandbox** (`~/.kiro/settings/sandbox.json` →
  `{"enabled": true}`) once done with the simulator-build loop.

## Verification owed
- [ ] Audit + run the app-target test suites (render grid↔world, view-model
  intents, mocked-HealthKit, multi-day claim, WatchConnectivity encode/decode +
  ledger reconciliation) against the acceptance criteria.
- [ ] Manual check of the HealthKit auth prompt + daily-claim flow on a
  simulator/device with Health data.

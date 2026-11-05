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
- [ ] **Debug mode (in-app debug menu).** A developer-only overlay for testing
  the economy/claim loop without walking around. All actions go through the
  frozen public APIs — the debug menu is pure UI + view-model intents, no new
  game rules, no core/persistence API changes.

  **Entry point.** A small button pinned to a screen corner (top-trailing,
  clear of `WalletHUD`) in `CityScreen`. Tapping it presents a debug panel
  (sheet or popover). Gate the whole thing behind `#if DEBUG` so it never ships
  in a release build.

  **Actions (starter set):**
  - [ ] **Add X of Y resource.** Pick a `ResourceType` (material / gold / food)
    and an amount, then credit the wallet. Use `GameState.credit(_:)` with a
    `ResourceBundle` holding just that resource; forward the mutation through the
    view-model so `onStateChanged` persists it (same path `place(...)` uses).
    New view-model intent, e.g. `debugCredit(_ type:, amount:)`. UI: a resource
    picker + stepper/text field + "Add" button.
  - [ ] **Reset all.** Wipe the city back to a fresh start — new `GameState`
    with the default starting wallet, cleared grid, and a cleared ledger. Needs
    a view-model `debugReset()` that swaps in a fresh `GameState` AND a
    persistence path to clear saved state + ledger entries (via the existing
    `PersistenceController` / store the app already holds — do NOT add new
    persistence APIs; if a clear isn't expressible with the frozen set, note the
    gap here instead of widening the API). DESTRUCTIVE: put a confirmation
    dialog in front of it.
  - [ ] **Simulate X days.** Credit the wallet as if N days of health activity
    were claimed, without real HealthKit data. Source metrics two ways, user's
    choice:
      - **Previous day's accumulation** — reuse the most recent claimed/known
        `HealthMetrics` (last ledger entry).
      - **Rolling 7-day average** — mean of the last week's entries' metrics.
    For each simulated day, build a `HealthMetrics`, run it through the economy
    (`BalanceConfig.default.economy.grant(for:)` → `ResourceBundle`) and credit
    the result ×N, OR push N synthetic `DailyLedgerEntry` rows through the real
    claim path (`LedgerService.claim` via `DailyClaimCoordinator`) so it
    exercises dedupe/backfill-cap too. Prefer the claim path — it tests more of
    the loop. UI: source toggle (prev-day / 7-day avg) + day-count stepper +
    "Simulate".

  **Notes / open questions (resolve during spec):**
  - Which economy source of truth does the sim use — `EconomyRates.default` or
    `BalanceConfig.default`? Match whatever the live claim loop uses so debug
    numbers equal real ones.
  - "Simulate days" via the ledger path is subject to the `backfillDayLimit`
    cap; decide whether debug should bypass that or respect it (respecting it is
    more honest).
  - Reset should also reset `AppContainer.claimableDays` / `lastClaim` so the
    HUD doesn't show stale claim state.
  - Keep every action idempotent-safe to spam; the panel is for rapid testing.

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

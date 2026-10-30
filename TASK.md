# Slim City — App Integration (Tasks 6–11)

## Goal
Build the iOS/watchOS app layer of Slim City on top of the already-complete,
tested domain core. The domain logic (economy, game state, building catalog,
daily health ledger, SwiftData persistence) is DONE and FROZEN in two local
Swift packages. This spec covers the remaining app-facing work: the SceneKit
isometric renderer, tap-to-place build UI, HealthKit integration, the daily
claim loop, the watchOS companion, and a final balancing/asset-readiness pass.

Three of these work streams are independent and should run in parallel. They all
depend ONLY on the frozen package APIs below — do not modify the packages'
public interfaces.

## Context: repository layout
- `SlimCityCore/` — pure Swift package, NO framework imports. Domain truth.
- `SlimCityPersistence/` — SwiftData package (depends on SlimCityCore).
- `SlimCity/SlimCity.xcodeproj` — iOS + watchOS app targets.
  - iOS target: `SlimCity`
  - watch target: `SlimCity Watch App`
  - NOTE: the watch app is currently DECOUPLED from the iOS app (embed phase +
    target dependency removed) so the iOS app builds without a developer team.
    Stream 3 must reconnect it (iOS target → General → embed the watch app;
    `WKCompanionAppBundleIdentifier` already matches `devplaceholder.VT6D75IM.SlimCity`).

## Context: frozen public API (build against these; do not change them)
From `SlimCityCore`:
- `ResourceType` (.material/.gold/.food), `ResourceBundle` (add/subtract/canAfford).
- `HealthMetrics(stepCount:activeEnergyKilocalories:exerciseMinutes:)`.
- `Economy` / `EconomyRates`: `economy.grant(for: HealthMetrics) -> ResourceBundle`.
- `GridPosition(column:row:)`.
- `BuildingDefinition` (id, displayName, cost, score, `modelName`, production).
- `BuildingCatalog.default` (ids: "house", "farm", "market"); `.definition(for:)`.
- `GameState` (columns, rows, wallet, buildings): `place(buildingID:at:using:) throws(PlacementError)`,
  `credit(_:)`, `score(using:)`, `building(at:)`, `isInBounds(_:)`, `isEmpty(at:)`.
- `PlacementError` (.outOfBounds/.tileOccupied/.insufficientResources/.unknownBuilding).
- `DailyLedgerEntry`, `DayKey`, `AntiCheatPolicy` (default `.passthrough`).
- `LedgerService` (injectable `Clock`/`Calendar`): `claim(entries:) -> (entries, ClaimResult)`,
  `claimableDays(in:)`. `ClaimResult(totalGrant, claimedDays)`.
From `SlimCityPersistence`:
- `PersistenceController(inMemory:)`: `saveGameState(_:)`, `loadGameState() -> GameState?`,
  `upsertLedgerEntry(_:)`, `loadLedgerEntries() -> [DailyLedgerEntry]`. CloudKit sync
  is OFF (single flip point noted in `PersistenceController.swift`).

## Context: environment / build notes (IMPORTANT)
- Swift 6.4 / Xcode 27.1, iOS 17+ / watchOS 10+ deployment.
- Package tests MUST be run via the provided helper, which works around a
  sandboxed SwiftPM: `SlimCityCore/scripts/test.sh` (redirects caches to a
  workspace-local `.swiftpm-home` and passes `--disable-sandbox`). Use the same
  flags for `SlimCityPersistence`.
- App targets (SceneKit/HealthKit/watch) require Xcode + a simulator to build and
  run; they cannot be verified with `swift build` alone. Where a step can't be
  built headlessly, state that clearly in the step's result rather than claiming
  a successful build.
- Keep `SlimCityCore` free of any framework import. Rendering, HealthKit, and
  WatchConnectivity code lives in the app targets (or new adapter files), never
  in the core package.
- Add the SlimCityCore / SlimCityPersistence packages to the app targets as
  local package dependencies if not already linked.

---

## Stream 1 — SceneKit isometric renderer + build UI (Tasks 6–7)

### Requirements
- Embed an `SCNView` in SwiftUI (`UIViewRepresentable`).
- Orthographic camera at a fixed ~45° isometric angle; basic lighting.
- Grid↔world coordinate mapping (pure function, unit-tested in a small helper
  type so it can be tested without a live scene).
- `BuildingNodeFactory(catalogName:) -> SCNNode`: primitive geometry by default
  (e.g. `SCNBox`), with a USDZ-by-name load path wired in that falls back to a
  primitive when no `<modelName>.usdz` asset exists. No code change should be
  needed later to swap in real art — only adding asset files.
- Render the current `GameState`'s buildings at their grid positions.
- SwiftUI HUD showing wallet totals (material/gold/food) and current score.
- Build menu to select a building type from `BuildingCatalog.default`.
- Tap handling via scene hit-testing → grid cell → `GameState.place(...)` through
  a thin view-model (NO game rules in the view). Show feedback for
  `.insufficientResources` and `.tileOccupied`.

### Acceptance criteria
- Grid↔world mapping has round-trip unit tests that pass headlessly.
- View-model intent tests: select building, place success, placement rejection
  surfaces the correct `PlacementError`.
- On a simulator, placing a building shows it in the isometric scene and
  decrements the wallet HUD. (State this as a manual/simulator check if it can't
  be run headlessly.)

---

## Stream 2 — HealthKit integration + daily claim loop (Tasks 8–9)

### Requirements
- `HealthKitService` behind a protocol so it can be mocked:
  - Request authorization for step count, active energy, exercise minutes.
  - Query per-day totals with `HKStatisticsCollectionQuery` anchored at local
    midnight (1-day interval).
  - Observer query + background delivery for passive updates.
  - Write results into `DailyLedgerEntry` values and persist via
    `PersistenceController.upsertLedgerEntry(_:)`.
  - Leave the `HKMetadataKeyWasUserEntered` manual-entry predicate behind the
    existing anti-cheat hook, OFF by default (set
    `DailyLedgerEntry.containsUserEnteredData` but don't act on it).
- Daily claim loop: on launch/foreground, use `LedgerService.claimableDays` /
  `claim(entries:)` to surface unclaimed days; a "collect" action credits the
  grant to `GameState` and persists both the ledger (claimed flags) and game
  state. Handle the already-claimed/empty state gracefully.

### Acceptance criteria
- `HealthKitService` tested against a protocol-mocked store: injected fake
  samples produce the expected `DailyLedgerEntry` values; auth-denied path
  handled. (These tests should run headlessly where they don't need the real
  HealthKit runtime; mark anything simulator-only.)
- Integration test across ledger + economy + persistence for a multi-day claim
  (can reuse the in-memory `PersistenceController`).
- On device/simulator with Health data, today's metrics tally and a claimable
  grant appears; collecting it raises the wallet. (Manual check.)

---

## Stream 3 — watchOS companion (Task 10)

### Requirements
- Reconnect the watch app to the iOS app (embed + dependency) — see repo layout
  note above.
- Watch app: request HealthKit authorization, collect daily metrics passively.
- Relay data to the phone via WatchConnectivity (or a shared App Group store);
  reconcile with the phone's ledger WITHOUT double-counting a day.
- Minimal watch UI: today's metrics + current resource totals.

### Acceptance criteria
- WatchConnectivity payload encode/decode unit tests (headless).
- Ledger reconciliation test: the same day arriving from watch and phone does
  not double-count (reuse `DayKey` as the dedupe key).
- On paired simulators, watch shows today's activity + resource totals and
  watch-collected data appears on the phone. (Manual check.)

---

## Stream 4 (RECONVERGE, after 1–3) — Balancing + asset/migration readiness (Task 11)

### Requirements
- Centralize all tunables (economy conversion rates, building costs/scores,
  ledger backfill cap) in one balance config in `SlimCityCore`. Do a tuning pass
  so the economy isn't degenerate (no instant-win).
- Prove the USDZ asset path: drop in one or two free low-poly models (e.g.
  Kenney) and confirm `BuildingNodeFactory` loads them in place of primitives
  with NO code change.
- Document the render-adapter seam and the CloudKit sync flip point.

### Acceptance criteria
- Balance-config tests (no degenerate economy) pass headlessly.
- At least one real USDZ model renders via the catalog instead of a primitive.
- Short written note on the render-adapter and CloudKit migration seams.

## Notes for the runner
- Streams 1, 2, and 3 are independent and may run in parallel. Stream 4 must run
  AFTER 1–3 land.
- Do not alter the public APIs of `SlimCityCore` or `SlimCityPersistence`.
- Prefer small, reviewable commits per step.
- When a step's verification requires Xcode/simulator and can't be done
  headlessly, say so explicitly instead of reporting a green build.

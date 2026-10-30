# Slim City — Project Constraints (always apply)

These rules apply to all work on this repo. They exist because agents have
previously tripped over them. Follow them unless a task explicitly overrides.

## Architecture boundaries (do not cross)
- `SlimCityCore/` is a PURE Swift package: NO imports of UIKit, SwiftUI,
  SceneKit, HealthKit, WatchConnectivity, or SwiftData. Domain logic only.
- `SlimCityPersistence/` depends on SlimCityCore and owns all SwiftData code.
  The dependency is one-way: core never imports persistence.
- Do NOT change the public APIs of SlimCityCore or SlimCityPersistence without
  an explicit task to do so — the app targets and tests build against them.
- Rendering (SceneKit), HealthKit, and WatchConnectivity live in the app
  targets under `SlimCity/`, never in the packages.

## Frozen public API (build against these; don't redefine)
- Core: `ResourceType`, `ResourceBundle`, `HealthMetrics`, `Economy`/`EconomyRates`,
  `GridPosition`, `BuildingDefinition` (has `modelName`, `production`),
  `BuildingCatalog.default` (ids: house/farm/market), `GameState`
  (`place(buildingID:at:using:) throws(PlacementError)`, `credit`, `score`),
  `PlacementError`, `DailyLedgerEntry`, `DayKey`, `AntiCheatPolicy` (`.passthrough`),
  `LedgerService` (`claim`, `claimableDays`), `ClaimResult`, `Clock`.
- Persistence: `PersistenceController(inMemory:)` — `saveGameState`,
  `loadGameState`, `upsertLedgerEntry`, `loadLedgerEntries`. CloudKit sync is OFF.

## Build & test environment
- Swift 6.4 / Xcode 27.1, iOS 17+ / watchOS 10+. Swift 6 concurrency is on:
  default-argument values evaluate in a NONISOLATED context, so don't put a
  `@MainActor` initializer call as a default argument.
- Package tests: run via `SlimCityCore/scripts/test.sh` (it redirects SwiftPM
  caches to a workspace-local `.swiftpm-home` and passes `--disable-sandbox`;
  the default SwiftPM sandbox path is not writable here). Use the same flags for
  SlimCityPersistence.
- App targets (SceneKit/HealthKit/watch) require Xcode + a simulator; they can't
  be verified with `swift build` alone. If a step can't be verified headlessly,
  SAY SO — do not claim a successful build you didn't run.
- Ignore build artifacts: `.build-sim/`, `.swiftpm-home/`, `sim-screenshot*.png`.

## Current project state — do NOT "fix" these
- The watch app is intentionally DECOUPLED from the iOS app (embed phase +
  target dependency removed) so the iOS app builds without an Apple Developer
  team. DO NOT re-add the watch embed/dependency. Watch code itself is fine and
  builds standalone.
- `CitySceneView` is UIKit-only by design; macOS falls back to a placeholder.
  Don't treat the macOS gray screen as a bug.
- The isometric camera uses an `SCNLookAtConstraint` on the grid center. Keep
  the look-at approach; don't revert to hand-set `eulerAngles`.

## Conventions
- Small, reviewable commits per logical change.
- Don't commit directly to `main`; use a feature branch.
- Match existing code style; prefer the patterns already in the file you edit.

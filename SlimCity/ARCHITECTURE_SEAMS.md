# Slim City — Architecture Seams (Task 11)

This note documents the two seams the spec calls out: the **render-adapter**
seam (how real art replaces placeholder geometry) and the **CloudKit sync**
flip point. It also records where the game's tunable balance now lives.

## 1. Render-adapter seam — primitives → real art, no code change

The render layer never hard-codes geometry. Every building node is produced by
`BuildingNodeFactory` (`SlimCity/SlimCity/Render/BuildingNodeFactory.swift`),
which resolves art **by name** from the app bundle:

```
BuildingDefinition.modelName  ──►  BuildingNodeFactory.node(forModelName:)
        "house"                         bundle.url(forResource: "house",
                                                   withExtension: "usdz")
                                     ├─ exists → load SCNScene(url:)  (real art)
                                     └─ absent → SCNBox placeholder   (fallback)
```

- `BuildingDefinition.modelName` (frozen core) is the lookup key. The default
  catalog uses `"house"`, `"farm"`, `"market"`.
- `BuildingNodeFactory.hasModelAsset(named:)` reports which branch will be taken
  without building a node (used by tests / diagnostics).
- **To ship real art: drop `house.usdz` / `farm.usdz` / `market.usdz` into the
  bundle. No code changes.** The factory loads them automatically; a building
  with no matching asset keeps its colored-box placeholder.

### Proven in this pass
`SlimCity/SlimCity/Models/house.usda` is a low-poly house authored in USD and
packaged to `house.usdz` (validated with `usdchecker`, "Success!"). Loading it
through the factory's exact code path yields **1 Xform containing 2 geometry
meshes** (walls + roof) — i.e. the real model renders in place of the primitive.
`farm`/`market` still fall back to primitives until their `.usdz` files are
added, demonstrating the mixed state is handled.

> Replacing `house.usda`→`house.usdz` with a nicer model (e.g. a Kenney
> low-poly building) is a pure asset swap: same filename, no recompile.

## 2. CloudKit sync flip point — one line, OFF in the MVP

Sync is deliberately **OFF**. The `@Model` classes in
`SlimCityPersistence/.../PersistenceModels.swift` are already CloudKit-shaped
(every stored property defaulted/optional; no `@Attribute(.unique)`;
relationships optional with inverses), so enabling sync needs **no model
changes**.

The single flip point is the `ModelConfiguration` in
`SlimCityPersistence/.../PersistenceController.swift`:

```swift
let configuration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: inMemory,
    cloudKitDatabase: .none   // ◄── flip to .automatic (or .private("iCloud.<container>"))
)
```

To enable sync later:
1. Add the **CloudKit** + **Background Modes (Remote notifications)**
   entitlements to the iOS (and watch) app targets.
2. Change `.none` → `.automatic` above.
That is the whole migration; the mapping layer (`GameSnapshot` /
`LedgerEntrySnapshot`) and the pure core are untouched.

## 3. Centralized balance (Task 11)

All tunables now live in one value: `BalanceConfig`
(`SlimCityCore/.../Economy/BalanceConfig.swift`).

| Tunable | Field |
|---|---|
| metric→resource rates | `economyRates` (`EconomyRates`) |
| building costs / scores / model names | `buildings` (`[BuildingDefinition]`) |
| ledger backfill cap | `backfillDayLimit` |

`BalanceConfig.default` is the tuned MVP balance. `BalanceConfigTests` asserts
the economy is **not degenerate**: one plausible active day (~10k steps, ~500
kcal, ~30 min) funds ~3 of the cheapest building — steady progress, not an
instant win — and the backfill cap is finite so idle time can't bank unlimited
resources. The change is **additive**: `EconomyRates.default`,
`BuildingCatalog.default`, and the `LedgerService` defaults are unchanged, so no
frozen public API was modified.

## App-layer verification boundary (environment note)

Per the spec's environment notes, the iOS/watchOS **app targets cannot be
built headlessly in this sandbox**: `xcodebuild` resolves the local SwiftPM
packages by spawning `sandbox-exec`, which the outer sandbox forbids
(`sandbox_apply: Operation not permitted`). This is an environment limit, not a
code error. The build + simulator run must be verified in Xcode / on a
simulator.

What *was* verified headlessly (via `swift test --disable-sandbox`):
- `SlimCityCore` — 41 tests incl. the new balance config (no degenerate economy).
- `SlimCityPersistence` — 11 tests (unchanged, still green).
- `SlimCityAppLogic` — 22 tests over the framework-free app logic: grid↔world
  round-trip, view-model placement intents + `PlacementError` surfacing, the
  multi-day claim integration, the WatchConnectivity payload codec, and ledger
  reconciliation (dedupe by `DayKey`, no double-count). This package compiles the
  SAME source files via symlinks, so there is no duplicate to drift. It is a dev
  harness and is NOT part of the shipping app.

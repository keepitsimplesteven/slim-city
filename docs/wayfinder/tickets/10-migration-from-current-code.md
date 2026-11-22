---
type: grilling
status: closed
blocked-by: [02, 03]
claimed: steven
---

# Migration from current code

## Question

What changes in the existing code? Today it has a daily ledger, a claim step with a backfill cap, and 1x1 buildings. Decide, per part, whether it stays, changes or goes: `LedgerService`, `GameState`, `BuildingCatalog`, persistence models, the claim UI. Keep HealthKit and camera. Check the code against each decision.

## Already decided (from tickets 03 and 04)

Needs: a state log with times, a time-source interface and a log-store interface (for server time later), sample-based timing in the sync path, a typed-in switch, background delivery and its entitlement, and reading the Exercise and Stand goals.

## Added by ticket 12

Needs: build state (scaffold, ready, open), effort bars per source, a construction worker cap, a swappable fill rule chosen in data, the "!" open flow, and 4 stages of visuals per build.

## Resolution

**Where code lives.**
- `SlimCityCore` (pure, no Apple frameworks): resources, building data, effects math, live earning, state log rules, construction, placement.
- `SlimCityPersistence`: all saving, including the new change log table.
- App target: HealthKit reading, drawing, screens.
- The public APIs of Core and Persistence may change under this ticket. When the spec is done, update `.kiro/steering/slim-city-constraints.md` (the frozen API list) to match.

**Saved games.** Old saves are wiped on first launch of the new version. Nothing old is kept.

**Keep, change, remove.**

| Part | Decision |
|---|---|
| `DayKey`, `Clock`, `SystemClock`, `FixedClock` | Keep. `Clock` also becomes the time-source interface (ticket 04). |
| `GridPosition` | Keep. Negative numbers allowed. |
| `CameraRig`, pan and zoom | Keep. |
| `HealthKitService`, `ActivitySummaryService`, `HealthDataProviding` | Keep, extend. |
| `HealthKitResourceSync` | Change. It is the seed for live earning. Keep "pay only the difference". |
| `ResourceType`, `ResourceBundle` | Change. Four resources: food, wood, stone, gold. `material` goes. |
| `BuildingDefinition`, `BuildingCatalog`, `PlacedBuilding` | Change to the ticket 02, 06, 09 and 12 model. |
| `GameState` | Change. Footprint checks, rotation, move, delete with refund, upgrade, cancel, bounds from Hall level. |
| `BalanceConfig`, `Economy`, `EconomyRates` | Change. Rates become the ticket 03 formula and data tables. |
| `CityViewModel`, `AppContainer`, `CityScreen` | Change. One wallet, edit mode, placement preview, building card, "!" open flow, no claim button. |
| `DebugPanel`, `DebugActions` | Change. See "Debug". |
| `IsometricGridMapper`, `BuildingEntityFactory`, `CitySceneView` | Change. Footprints, rotation, 4 build stages. |
| `GameSnapshot`, `PersistenceModels`, `PersistenceController` | Change. New tables. CloudKit-shaped rules stay. Sync stays off. |
| `LedgerService`, `DailyLedgerEntry`, `DailyClaimCoordinator`, claim HUD, 7-day backfill | Remove. All once-per-day logic goes. |
| `StoredLedgerEntry`, `UserDefaultsGrantRecordStore` | Remove. Paid progress moves into Persistence. |
| `ResourceMode` and the two wallets | Remove. |
| Building `score` | Remove (ticket 02). |
| `AntiCheat` | Change. Becomes the typed-in switch (ticket 04). |
| Watch app, `PhoneConnectivityManager`, `LedgerReconciler`, `WatchHealthPayload` | Leave as they are, unused by the new sync, not embedded. |

**One wallet.** There is one wallet and it is saved.

**Debug.** Debug adds go on top of what was earned and never change paid progress. Debug tools are fake progress (not fake days), add resources, and reset. All under `#if DEBUG`. This also removes the known "refresh wallet does nothing" bug.

**Grid and coordinates.**
- The grid is centered on cell (0, 0), with negative numbers allowed. Growing adds a ring on every side, so nothing shifts.
- A placed building stores its **anchor as its corner**: the lowest column and row it covers. A footprint covers the anchor plus 0..width-1 and 0..height-1. This avoids needing a "center" of a 2x3.
- A quarter turn swaps width and height, and the anchor is the new corner. Edit mode keeps the building's corner in place when turning, unless that does not fit.

**Start of a game (ticket 08 changed here).**
- The player starts with exactly the resources to place the Village Hall and, maybe, a first house. The amounts are data.
- The Hall is not free any more. It is a scaffold like every build (ticket 12), paid from the starting wallet. It needs a lot of effort.
- Nothing is tracked until the Hall scaffold is placed.
- Before the Hall exists, the player has 1 person and a cap of 1 construction worker, so the Hall can be built. Those numbers are data. This was my call. The Hall's own cap then takes over (ticket 12).

**New pieces:**
- Live earning (ticket 03, replaces the claim path).
- Effects engine: adds, then multiplies (ticket 02).
- Construction engine: scaffold, bars, "!" open (ticket 12).
- State log with times, behind a log-store interface and a time-source interface (ticket 04).
- Feature registry with a shared stub screen (ticket 09).
- Paid progress per resource per day, kept in Persistence.

**HealthKit (app target).** Read Exercise and Stand goals, workouts and samples with start and end times, and steps. Turn on background delivery, add the entitlement, observe the underlying sample types and re-read the summary on wake (ticket 01).

**History.** The change log keeps 7 days (a data value). The Records building may later need longer history, such as daily totals. Not decided now.

**Watch.** No plan yet. It will probably be a read-only complication. For the MVP it may show current resources. A deeper look comes after the MVP.

**Verification limit.** Core and Persistence rules can be tested headless with `SlimCityCore/scripts/test.sh` flags and `--disable-sandbox`. These need Xcode and a device and cannot be checked headless: HealthKit reads, background delivery, the entitlement, drawing, gestures and screens. Tasks must say so per step.

**Tests.** Existing tests for claim, ledger, wallet modes and the 1x1 grid get rewritten with the code they cover.

**Suggested slices for the task list:** (1) resources and data tables, (2) buildings, placement and footprints, (3) effects and live earning, (4) state log and time source, (5) construction, (6) persistence, (7) app wiring and debug, (8) HealthKit reads, (9) screens and drawing.

## Added by ticket 13

Needs: a small screen router, a badge system on buildings, a dialog element, a bottom drawer element, a header with people, a build carousel, and one building sheet with state bodies.

# Slim City — TODO / Deferred Work

Running list of things intentionally deferred. Not blocking the MVP loop
(health data → resources → place buildings), which is working.

## Gameplay / rendering
- [ ] **Pannable / zoomable map.** The isometric SceneKit camera is currently
  fixed (orthographic, look-at the grid center). Add pan to move the view and
  pinch/scroll to zoom. Likely a pan + pinch gesture on the `SCNView` in
  `CitySceneView` driving the camera node (or `allowsCameraControl` as a quick
  first pass, then a constrained custom gesture so it stays isometric).
  Keep it from fighting the tap-to-place gesture.

## Platform / build
- [ ] **Reconnect the watch app to the iOS app** (embed phase + target
  dependency) once an Apple Developer account / signing is sorted. Currently
  decoupled so the iOS app builds without a team. Watch code (Task 10) is done
  and builds standalone. `WKCompanionAppBundleIdentifier` already matches.
- [ ] **No macOS render path.** `CitySceneView` is UIKit-only; on a Mac build
  the center falls back to a gray placeholder. Add an AppKit
  (`NSViewRepresentable`) branch if we ever want it running on macOS. Run on
  an iPhone simulator for now.
- [ ] **Template leftover:** iOS target `productName` is still `MyApp` and the
  entry file is `MyApp.swift`. Cosmetic; rename when convenient.
- [ ] **Re-enable the command sandbox** (`~/.kiro/settings/sandbox.json` →
  `{"enabled": true}`) once we're done with the simulator-build loop.

## Designed-for, out of MVP scope (seams already in place)
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

## Verification still owed
- [ ] Audit + run the app-target test suites (render grid↔world, view-model
  intents, mocked-HealthKit, multi-day claim, WatchConnectivity encode/decode +
  ledger reconciliation) against the spec's acceptance criteria.
- [ ] Manual check of the HealthKit auth prompt + daily-claim flow on a
  simulator/device with Health data.

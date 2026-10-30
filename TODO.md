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

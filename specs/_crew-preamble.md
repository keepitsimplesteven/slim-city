# Crew Compose preamble — paste this ABOVE your feature description

Steering (.kiro/steering/slim-city-constraints.md) guards task EXECUTION but is
NOT injected into Crew's Refine step. So paste this preamble into the Compose
box before your feature text, so Refine shapes the spec correctly from the start.

---

Context for this task:
- iOS 17+/watchOS 10+ app, Swift 6.4/Xcode 27.1. Game logic lives in the pure
  `SlimCityCore` package (no UI/framework imports) + `SlimCityPersistence`
  (SwiftData). Do NOT modify those packages' public APIs.
- Render/HealthKit/WatchConnectivity code lives in the `SlimCity/` app targets.
- The watch app is intentionally DECOUPLED from the iOS app — do NOT re-add the
  watch embed/dependency.
- App-target (SceneKit/HealthKit/watch) work needs Xcode + a simulator to
  verify; if a step can't be verified headlessly, say so rather than claiming a
  green build. Package tests run via `SlimCityCore/scripts/test.sh`.
- Use a feature branch; small commits; keep the isometric camera's look-at
  approach.

My feature/bug:
<describe the work here>

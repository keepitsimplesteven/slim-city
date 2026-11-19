---
type: research
status: closed
blocked-by: []
claimed: steven
---

# HealthKit capabilities

## Question

What can HealthKit give us, and how fast? Find, from Apple documentation:

1. Can we read the user's current Move, Exercise and Stand **goals** (so yield can be a percent of a goal that the user may change)?
2. Can we read ring progress as samples with start and end **timestamps**, so earning can be tied to when a workout finished?
3. How late do samples arrive after a workout (sync delay from Watch to phone)? Is background delivery usable?
4. Can user-entered samples be told apart from device samples?
5. Can we read steps for gold?
6. Can we read Fitness awards (perfect week and so on)? Notes say probably not.

Record: which API for each, limits, and anything that breaks the "live earning" idea.

## Resolution

Full findings with source links: [research/01-healthkit-capabilities.md](../research/01-healthkit-capabilities.md).

1. **Goals:** yes. `HKActivitySummary` exposes Move, Exercise and Stand goals. Docs do not say when a mid-day goal change takes effect.
2. **Timestamps:** partly. Activity summaries are day-level with no times. Samples and `HKWorkout` have `startDate` and `endDate`. Apple does not say summed samples equal the ring value.
3. **Sync delay:** the Watch-to-phone delay is not documented. Background delivery works with the `com.apple.developer.healthkit.background-delivery` entitlement, wakes at most hourly for step count on iOS, and may not read data while the phone is locked. Docs do not say the activity summary type can be observed in the background.
4. **User-entered:** yes. `HKMetadataKeyWasUserEntered` is set by the writing app. A missing key does not prove a device sample. Summaries have no such flag.
5. **Steps:** yes. Cumulative quantity sample, separate from the summary.
6. **Awards:** no. No award API found. Medals must be built in.

**What this means for live earning:**
- Credit must key off sample or workout `endDate`, not the summary.
- Late-syncing samples keep their old `endDate`.
- Wake-ups are limited, so "live" means "as fast as HealthKit lets us", often about hourly.
- Goals can change under a "percent of goal" payout.

**Current app code:**
- Reads Move, Exercise, Stand via `HKActivitySummaryQuery` (`SlimCity/SlimCity/Health/ActivitySummaryService.swift`) and steps, energy, exercise minutes (`HealthKitService.swift`).
- Gaps: reads only the Move goal, ignores workouts, no observer or background delivery, and the entitlements file lacks the background-delivery entitlement.

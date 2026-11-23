# Research 01: HealthKit capabilities

Ticket: `/Users/stevenalbers/projects/kiro-workspace/slim-city/docs/wayfinder/tickets/01-healthkit-capabilities.md`
Researched: 2026-11-19. Sources are Apple developer documentation only. The doc pages are JavaScript-rendered, so I read Apple's own documentation JSON behind each page (`https://developer.apple.com/tutorials/data/documentation/healthkit/<page>.json`). Each claim below cites the human-facing page URL, and the JSON holds the same text.

Evidence labels: **Confirmed** means Apple's docs state it. **Inferred** means it follows from the docs but is not stated. **Not confirmed** means Apple's docs are silent.

## Summary

| # | Question | Answer |
|---|----------|--------|
| 1 | Read current Move/Exercise/Stand goals? | Yes |
| 2 | Ring progress as samples with start/end timestamps? | Partly. Activity summaries are day-level with no timestamps. Underlying samples and workouts have start/end. |
| 3 | Sync delay known? Background delivery usable? | Delay: unclear (not documented). Background delivery: usable with limits. |
| 4 | Tell user-entered samples from device samples? | Yes, with a caveat |
| 5 | Read steps? | Yes |
| 6 | Read Fitness awards? | No (no API found) |

## 1. Move, Exercise and Stand goals

**Yes. Confirmed.** `HKActivitySummary` carries the goals alongside the progress values. It is read with `HKActivitySummaryQuery`.

- `HKActivitySummary` holds "the move, exercise, and stand data for a given day". It is read through `HKActivitySummaryQuery`. https://developer.apple.com/documentation/healthkit/hkactivitysummary
- Move goal: `activeEnergyBurnedGoal` (energy units). https://developer.apple.com/documentation/healthkit/hkactivitysummary/activeenergyburnedgoal
- Move goal in move-time mode: `appleMoveTimeGoal` (time units). https://developer.apple.com/documentation/healthkit/hkactivitysummary/applemovetimegoal
- Exercise goal: `exerciseTimeGoal` (optional, time units). https://developer.apple.com/documentation/healthkit/hkactivitysummary/exercisetimegoal
- Stand goal: `standHoursGoal` (optional, `count()` units). https://developer.apple.com/documentation/healthkit/hkactivitysummary/standhoursgoal
- `activityMoveMode` says whether the Move ring is measured in active energy or move time. https://developer.apple.com/documentation/healthkit/hkactivitysummary/activitymovemode
- The Move ring can be move time instead of calories. The doc says this applies to "younger users". https://developer.apple.com/documentation/healthkit/hkactivitysummary/applemovetime
- Authorization: use `HKObjectType.activitySummaryType()` to request read permission. Apps cannot request write permission for summaries. https://developer.apple.com/documentation/healthkit/hkobjecttype/activitysummarytype()
- The docs list two Exercise goal properties, `exerciseTimeGoal` and `appleExerciseTimeGoal`. I read only the first. I did not check how the two differ.

Limits and unknowns:

- **Not confirmed:** whether a goal change made mid-day updates today's summary immediately, or only applies from the next day. Apple's docs describe each goal as "the user's daily goal" and say nothing about change timing. If each day's summary stores the goal that applied on that day, past days would keep their own goals. This is **inferred** from the one-summary-per-day shape and is not stated.
- **Confirmed:** each summary covers one calendar day, midnight to midnight. The day may be longer or shorter than 24 hours. https://developer.apple.com/documentation/healthkit/hkactivitysummary/datecomponents(for:)
- **Confirmed:** `HKActivitySummary` objects are mutable in memory, but edits do not change the store and cannot be saved. https://developer.apple.com/documentation/healthkit/hkactivitysummary
- If the user denies read permission, the app sees no data and is not told. "an app isn't aware when the user denies permission to read data." https://developer.apple.com/documentation/healthkit/protecting-user-privacy

## 2. Ring progress with start/end timestamps

**Partly. Confirmed.**

- `HKActivitySummary` is a per-day aggregate. Its only time field is the day's date components, with no start or end time of any activity inside the day. https://developer.apple.com/documentation/healthkit/hkactivitysummary/datecomponents(for:)
- Underlying data does have timestamps. Every `HKSample` has `startDate` and `endDate`. Interval data such as step count uses different start and end dates. https://developer.apple.com/documentation/healthkit/hksample/startdate and https://developer.apple.com/documentation/healthkit/hksample/enddate
- The ring inputs exist as samples:
  - Move: `activeEnergyBurned` quantity samples. https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/activeenergyburned
  - Exercise: `appleExerciseTime` quantity samples (type page fetched; the summary page confirms the ring measure). https://developer.apple.com/documentation/healthkit/hkactivitysummary/appleexercisetime
  - Stand: `HKCategoryValueAppleStandHour` category samples ("whether the user stood during the sample's duration"). https://developer.apple.com/documentation/healthkit/hkcategoryvalueapplestandhour
- Workouts: `HKWorkout` is an `HKSample`, so it has `startDate` and `endDate`. https://developer.apple.com/documentation/healthkit/hkworkout
- Workouts feed the rings. On watchOS the Move ring follows the associated active energy samples and Exercise follows time the watch senses as exertion. On iOS, the Exercise ring increases by the workout's total duration. Stand rises by one hour per wall-clock hour the workout overlaps. https://developer.apple.com/documentation/healthkit/hkworkout
- **Caveat, confirmed:** "Sample data may be condensed and/or coalesced by HealthKit." So sample boundaries may not match what the watch originally wrote. https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/stepcount (same sentence on the active energy page)
- **Not confirmed:** that the sum of `appleExerciseTime` or `activeEnergyBurned` samples equals the ring value in `HKActivitySummary`. The docs describe both, but state no guaranteed equality. Treat the summary as the source of truth for ring progress, and use samples only for timing.

Implication: "earning tied to when a workout finished" works through `HKWorkout.endDate`, or sample `endDate`. It cannot work through the activity summary alone.

## 3. Sync delay and background delivery

**Delay: not documented.** I found no Apple doc page giving a Watch-to-iPhone sync delay. The docs say the system "automatically records samples on iPhone and Apple Watch" (step count page) and that observer queries respond to "changes made by other apps and devices" (https://developer.apple.com/documentation/healthkit/hkobserverquery). Neither states a latency. Do not build on an assumed number. Measure it on a real device.

**Background delivery: usable, with limits. Confirmed** from https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:) unless noted:

- iOS 15 and later needs the `com.apple.developer.healthkit.background-delivery` entitlement. Without it, `enableBackgroundDelivery` fails with an authorization-denied error. The entitlement is a boolean that defaults to false. https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.healthkit.background-delivery
- HealthKit wakes the app when a process saves or deletes samples of the type, at most once per period of the requested frequency. Some types have an hourly maximum. "on iOS, `stepCount` samples have an hourly maximum frequency."
- On watchOS, most types are hourly at best. A short list (heart-rate events, VO2 max and similar) can be `immediate`. Background updates share a budget with background refresh tasks: four per hour, and only with a complication on the active watch face.
- Frequencies are `immediate`, `hourly`, `daily`, `weekly`. https://developer.apple.com/documentation/healthkit/hkupdatefrequency/immediate (and sibling pages)
- Observer queries should be set up in `application(_:didFinishLaunchingWithOptions:)`. The update handler's completion handler must be called. If the app fails to call it three times, HealthKit stops sending background updates.
- Background delivery does not run in the Simulator. Test on a device.
- The observer update handler receives no sample data, only the fact that something changed. A follow-up query is needed. https://developer.apple.com/documentation/healthkit/executing-observer-queries
- **Locked device, confirmed:** the store is encrypted when the device is locked, so "your app may not be able to read data from the store when it runs in the background." https://developer.apple.com/documentation/healthkit/protecting-user-privacy
- Foreground: `HKActivitySummaryQuery` with an `updateHandler` keeps running and fires when matching summaries are saved or modified. https://developer.apple.com/documentation/healthkit/hkactivitysummaryquery/updatehandler
- **Not confirmed:** whether `enableBackgroundDelivery` accepts the activity summary type. The API takes an `HKObjectType`, and `HKObserverQuery` takes an `HKSampleType`. Apple's docs do not say activity summaries can be observed in the background. **Inferred:** to observe in the background, observe the underlying sample types (`activeEnergyBurned`, `appleExerciseTime`, `HKWorkoutType`) and re-query the summary on wake. Not stated by Apple.
- **Not confirmed:** the actual frequency for `activeEnergyBurned`, `appleExerciseTime` and workouts on iOS. Only step count has a documented hourly cap.

## 4. User-entered versus device samples

**Yes, with a caveat. Confirmed.**

- `HKMetadataKeyWasUserEntered` is a metadata key that "indicates whether the sample was entered by the user." https://developer.apple.com/documentation/healthkit/hkmetadatakeywasuserentered
- Read it from `HKObject.metadata`. https://developer.apple.com/documentation/healthkit/hkobject/metadata
- Samples also carry `source`, an `HKSource` naming the app or device that created them. https://developer.apple.com/documentation/healthkit/hkobject/source
- **Caveat (docs wording):** the key page tells the writer to set it to true for user-entered samples. It does not say HealthKit sets it for every manual Health-app entry, and it does not say the key is always present. Apple documents the key as a writer-set flag. Absence of the key is not proven to mean "device sample". Combining it with `source` is a reasonable second check, but Apple does not describe that as an anti-cheat method.
- Activity summaries have no such flag. The check applies to underlying samples only.
- Metadata is mutable only at creation, and a third-party app can write arbitrary metadata, so this is a hint and not proof.

## 5. Steps for gold

**Yes. Confirmed.** `HKQuantityTypeIdentifier.stepCount` is a cumulative count-unit quantity. "The system automatically records samples on iPhone and Apple Watch." https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/stepcount

- It needs read authorization for the `stepCount` type.
- Observer and background delivery work, with an hourly cap on iOS (see Q3).
- Data may be condensed or coalesced (same page).
- Steps are not part of `HKActivitySummary` at all. The summary has no step field. The app must query step samples or statistics separately.

## 6. Fitness awards (perfect week and so on)

**No. Not confirmed, and I found no API.** I listed the top-level topics of the HealthKit framework page (https://developer.apple.com/documentation/healthkit) and searched its documentation JSON for "achievement", "award", "badge" and "perfect". Nothing matched. A guessed `hkachievement` page does not exist (404). Apple's docs expose no award or badge type. This matches the ticket's expectation. Absence from the docs does not prove Apple has no private data, only that apps have no documented way to read awards.

Workaround, **inferred** (not Apple guidance): compute your own "perfect week" or streak from daily `HKActivitySummary` values and goals (Q1).

## What the app already does

Searched `/Users/stevenalbers/projects/kiro-workspace/slim-city/SlimCity` (Swift files, entitlements, plists; `.build*` folders excluded). Findings:

| File | What it reads |
|------|---------------|
| `/Users/stevenalbers/projects/kiro-workspace/slim-city/SlimCity/SlimCity/Health/ActivitySummaryService.swift` | `HKActivitySummaryQuery` (no `updateHandler`) over a date range. Reads `activeEnergyBurned`, `activeEnergyBurnedGoal`, `appleExerciseTime`, `appleStandHours`. Requests read access for `HKObjectType.activitySummaryType()`. |
| `/Users/stevenalbers/projects/kiro-workspace/slim-city/SlimCity/SlimCity/Health/ActivityGrant.swift` | Pure economy. `HealthKitResourceSync` pulls a 7-day summary window and credits only `target - alreadyGranted` per resource per day. Gold = % of Move goal (max 100). Food = 1 per exercise minute (max 30). Material = 1 per stand hour (max 12). First sync records past days as already granted. |
| `/Users/stevenalbers/projects/kiro-workspace/slim-city/SlimCity/SlimCity/Health/HealthKitService.swift` | Per-day `HKStatisticsCollectionQuery` sums for `stepCount`, `activeEnergyBurned`, `appleExerciseTime`. Flags days that contain `HKMetadataKeyWasUserEntered == true` samples via an `HKSampleQuery` (recorded only, policy is passthrough). Also has `HKObserverQuery` plus `enableBackgroundDelivery(frequency: .daily)` in `startObserving`. |
| `/Users/stevenalbers/projects/kiro-workspace/slim-city/SlimCity/SlimCity/Health/HealthDataProviding.swift` | Protocol and types for the above. |
| `/Users/stevenalbers/projects/kiro-workspace/slim-city/SlimCity/SlimCity Watch App/Health/WatchHealthCollector.swift` | `HKStatisticsQuery` for today's steps, active energy and exercise minutes. |

Gaps and problems found in the code, measured against the docs above:

- **Exercise and Stand goals are not read.** Only `activeEnergyBurnedGoal` is used. `exerciseTimeGoal` and `standHoursGoal` are available (Q1) but unused. Food and material use fixed caps (30 and 12), not a share of the user's goal.
- **Move-time mode is ignored.** `activityMoveMode` and `appleMoveTime` are never read. The goal conversion `doubleValue(for: .kilocalorie())` on `activeEnergyBurnedGoal` would be wrong for a user whose Move ring is time-based (per the `appleMoveTime` doc). I did not read how `activeEnergyBurnedGoal` behaves in move-time mode, or what happens when an energy unit is applied to a quantity with time units. **Not confirmed.**
- **Background delivery likely fails today.** `/Users/stevenalbers/projects/kiro-workspace/slim-city/SlimCity/SlimCity.entitlements` has `com.apple.developer.healthkit` and `com.apple.developer.healthkit.access` only. It lacks `com.apple.developer.healthkit.background-delivery`. Per the docs (Q3) `enableBackgroundDelivery` fails without it on iOS 15 and later. I did not check the Xcode project file for a separate entitlement source, and I did not search `Info.plist` for background modes.
- **Observation is not wired up.** `HealthKitService.startObserving` is defined and a no-op stub exists at `/Users/stevenalbers/projects/kiro-workspace/slim-city/SlimCity/SlimCity/AppContainer.swift` line 240. A grep found no call to `startObserving` outside those definitions. I did not trace every call path, so confirm before relying on this.
- **Frequency is `.daily`.** That is the slowest practical option for "live earning". Step count is hourly at best on iOS (Q3).
- **The activity-summary path (the one that pays out) has no observer, no `updateHandler` and no background delivery.** It runs a one-shot query when `HealthKitResourceSync.sync` is called.
- **Workouts are not read anywhere.** No `HKWorkout` or `HKWorkoutType` usage found.
- **Awards are not read** (consistent with Q6).

## Findings that break or strain "live earning"

The idea: credit resources as HealthKit syncs, using sample timestamps and the user's current ring goals.

1. **No ring timestamps.** `HKActivitySummary` is per day with no time inside the day. "Credit at the moment a ring grew" is impossible from the summary. Timing has to come from workout or sample `endDate`, and the sum of samples is not guaranteed to match the ring (Q2). **Confirmed.**
2. **Sample timestamps are when activity happened, not when the data arrived.** Late-syncing data arrives with old `endDate` values. Crediting by sample time would back-date earnings, and a ledger keyed on time must tolerate late arrivals. **Inferred** from the sample model. The sync delay is not documented (Q3).
3. **"Live" is capped by delivery frequency.** Background wake-ups are at most hourly for step count on iOS, and the cap for ring-related types is not stated. The app can be woken, and a locked phone may block reads (Q3). Real-time credit while the app is closed is not guaranteed. Foreground (`updateHandler`) is the only documented continuous path. **Confirmed.**
4. **Activity summary background delivery is unconfirmed.** Apple does not say the summary type can be observed in the background (Q3). **Not confirmed.**
5. **Goals can change.** The user can change a goal, and Apple does not document when a change applies (Q1). A "percent of goal" payout computed live can shrink or grow after the fact. The current idempotent `target - alreadyGranted` design in `ActivityGrant.swift` never claws back, so a lowered goal gives a one-way bonus. **Inferred** from the code and docs.
6. **Move ring may not be calories.** Move-time mode exists (Q1). **Confirmed.**
7. **Manual entries can feed the rings and the summary has no flag.** The user-entered check only works on underlying samples, and it is writer-set (Q4).
8. **Condensed samples.** HealthKit may coalesce samples, so sample boundaries can shift after you read them (Q2). **Confirmed.**

## Open items needing a real device (docs cannot answer)

- Watch-to-iPhone delay for workouts, active energy, exercise minutes, stand hours.
- Whether background delivery fires for `activeEnergyBurned`, `appleExerciseTime` and `HKWorkoutType`, and how often in practice.
- How a mid-day goal change shows up in `activeEnergyBurnedGoal` for today and past days.
- Whether summed samples match the activity summary values.

## Source list

All under `https://developer.apple.com/documentation/`:
- `healthkit/hkactivitysummary` and its property pages (`activeenergyburned`, `activeenergyburnedgoal`, `applemovetime`, `applemovetimegoal`, `appleexercisetime`, `exercisetimegoal`, `applestandhours`, `standhoursgoal`, `activitymovemode`, `datecomponents(for:)`)
- `healthkit/hkactivitysummaryquery`, `.../updatehandler`, `healthkit/executing-activity-summary-queries`
- `healthkit/hkobjecttype/activitysummarytype()`
- `healthkit/hkobserverquery`, `healthkit/executing-observer-queries`, `healthkit/hkobserverquerycompletionhandler`
- `healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:)`, `healthkit/hkupdatefrequency`
- `bundleresources/entitlements/com.apple.developer.healthkit.background-delivery`
- `healthkit/hkmetadatakeywasuserentered`, `healthkit/hkobject/metadata`, `healthkit/hkobject/source`
- `healthkit/hkworkout`, `healthkit/hksample/startdate`, `healthkit/hksample/enddate`
- `healthkit/hkquantitytypeidentifier/stepcount`, `.../activeenergyburned`
- `healthkit/hkcategoryvalueapplestandhour`
- `healthkit/protecting-user-privacy`
- `healthkit` (framework topic list, for the awards search)

---
type: grilling
status: closed
blocked-by: []
claimed: steven
---

# HUD and live feedback

## Question

How does the player see earning that happens in the background? Decide: what the HUD shows (four resources, daily caps, ring progress), how a payout is shown when a sync arrives, how stale data is shown (HealthKit may sync only about hourly, ticket 01), how the midnight reset and the food shortage warning appear, and whether local notifications tell the player a build is ready or food is short.

Needs HealthKit permission wording from ticket 16.

## Added by ticket 13

Header holds resources and people. Buildings show data-driven badges (several at once) and always-on progress rings while under construction. Decide the badge list and reasons for the MVP, and whether warnings use a banner or the bottom drawer.

## Resolution

**Header.** Four resources (whole numbers, truncated) and people as `used/total` with a person icon. Tapping a resource opens a **popover right under it** (not a drawer). The popover shows that day's progress toward the cap, the goal, and the base and building bonus. The header text changes color (gold or similar, a data value) when the day's cap is reached, so it reads without a tap. Food turns red at or below 0.

**Payout feedback.**
- Main form: a **center modal** "here is what you collected since you were last here". It shows when the app opens after a gap, and also when a sync lands while the app is open.
- A config option swaps in a minimal form: the header number counts up with a floating "+12". Merge syncs that arrive close together. Default is the modal. Tune after play.
- The sync cadence is not known. HealthKit may deliver about hourly (ticket 01).

**Stale data.** A small runner or heart icon in the header. Tap it for "last synced xx ago". It is bold when the sync is recent and fades when old (about 1 hour, a data value).

**Day ledger.** On the first open of a new day, the same modal style shows a ledger of the previous day: resources collected, food eaten, and the grace-day state if food was short. If several days passed, it shows each day. The 7-day catch-up (ticket 03) bounds it.

**Food eaten at intervals (changes ticket 05).** Food is consumed at regular intervals through the day, not in one chunk at midnight. The interval is data. Total per day still equals `people x food rate`, so the day ledger sums it. Shortage and the grace day (ticket 05) still apply; the check moves from midnight to the interval step. Open detail for ticket 11: the interval length and how a catch-up replays missed intervals.

**Warnings.** No banner. Warnings are badges, the red food number, the ledger and the popover. Details go to the bottom drawer if needed.

**Building badges (data-driven, several at once).** Each is a separate badge floating on the building, no "+N" overflow.
| Badge | Means |
|---|---|
| `!` | Ready, tap to open |
| Rings | Under construction. One ring per cost resource, always visible |
| Needs workers | No worker where one is needed |
| Needs food | Hungry people |
Unlock lock badge: dropped. A locked building cannot be placed, so none exists on the city. Later: `?` for quests.

**Notifications.** Two local notifications, both off until the player allows them: build ready, and food short. If the app is open, the event shows in-app instead. Notify only when the app is not open. At most one a day each (data). Wording and the permission ask go to ticket 16.

**Passed on:**
- `05`: food step moves from midnight to intervals.
- `10`/spec: a modal element, a popover element, a badge list in data, a notification service behind an interface.
- `11`: food interval length.
- `14`: look of the popover, modal, runner icon, badges (user reacts to the prototype).
- `16`: notification permission wording.

## Amended by ticket 14 (round 2)

The day ledger is dropped. The one "collected" modal shows resources gained, food eaten, daily max reached (gold text), and time since last collected. People use a popover under the header, not a drawer. Build bars are not shown in the modal.

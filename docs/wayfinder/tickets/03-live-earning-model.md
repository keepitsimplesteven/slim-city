---
type: grilling
status: closed
blocked-by: [01]
claimed: steven
---

# Live earning model

## Question

How does a HealthKit sync turn into resources? Decide: what is credited per sync, how the per-ring percent maps to 0 to 100 resources, how the 1.5x daily cap is tracked per resource, what "midnight" means across time zones, what happens to partial progress, and how a changed ring goal is handled mid-day.

Known: rings pay up to 100 each at 100%, capped at 1.5x, reset at local midnight, multiplier configurable.

## Resolution

**Formula, per resource, per day:**

`earned = (base + sum of building adds) x min(progress, cap) x product of building multipliers`

- `base` is 100 per ring. It is a data value.
- `progress` is the ring value divided by that day's goal. A closed ring is 1.0.
- `cap` is 1.5. It is a data value, easy to change for testing. It limits ring progress only. Buildings multiply after the cap, so earned can pass 150.
- Building adds raise the daily maximum, but they are still scaled by progress. With no exercise, nothing is earned.
- Worked example, ring at 50%, one farm (+10), multiplier 1.1: (100 + 10) x 0.5 x 1.1 = 60.5.

**Syncs:**
- Each sync pays only the new part. Per ring per day, the app remembers the highest progress already paid. It pays the difference.
- The rate applies at the moment of the sync. Ticket 04 decides which building state counts.
- Progress never goes down, so earned never goes down.

**Goals:**
- The goal for a day is the goal the app sees at the start of that day. Edits during the day count from the next day.
- If the app was closed at midnight, it uses the first goal it sees that day. For a missed day, it uses the goal HealthKit stored for that day. HealthKit may hold the last goal of that day, not the first. If skipped-day tracking turns out to be exploitable, rework this.

**Days:**
- A day ends at midnight on the phone's local clock. Progress and cap reset.
- When the app opens, it looks back up to 7 days and pays unpaid progress, still capped at 1.5 per day.

**Numbers:**
- Fractions are kept exactly inside. The screen shows the whole number cut off, never rounded. A cost is checked against the exact amount.

**Passed on:**
- `04`: whose building state counts, and the skipped-day risk.
- `07`: gold from steps. Steps have no goal, so the percent rule may not fit.
- `10`: replace the per-unit rates and the claim step in `LedgerService` and `BalanceConfig`.

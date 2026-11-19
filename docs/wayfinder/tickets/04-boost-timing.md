---
type: grilling
status: closed
blocked-by: [01, 03]
claimed: steven
---

# Boost timing and anti-gaming

## Question

How do we stop "build or move workers after the workout, then sync" tricks? Known idea: compare the timestamp of a building or worker change with the workout completion timestamp. Fallback idea: a delay of about one hour before changes take effect.

Decide: which timestamp wins, what a change affects (past samples, future samples), whether the delay is needed at all, and what the user sees while a change is pending.

## Already decided (from ticket 03)

Each sync pays only the new ring progress since the last sync. Ring totals carry no times (see ticket 01). Skipped-day tracking uses the goal stored for that day and may be exploitable. Check that here.

## Resolution

**Rule:** a payout uses the buildings and people as they were when the exercise **started** (the sample start time). Later changes never touch earlier exercise, even if the workout syncs after the change. A workout that spans a change gets the old state.

**Totals and times:**
- The ring total from HealthKit says how much progress is new, because it matches what the user sees.
- The samples (energy, exercise minutes, stand hours) say when it happened. New progress is split across the new samples by size.
- If no samples have arrived yet, price the progress at the state as of the last sync.
- Apple does not promise that samples add up to the ring (ticket 01), so the ring stays the source of truth for amounts.

**State log:**
- The app keeps an append-only log with a time on each entry: built, upgraded, moved, deleted, people placed or moved.
- To price a sample, look up the state at its start time.
- Keep the last 7 days, the same as the catch-up window from ticket 03.
- A building deleted later still counts for exercise done before it was deleted.

**No delay.** There is no one-hour delay and no setting for one.

**Clock:**
- The log uses the phone clock for now. A player can change it. This is accepted for a single-player game.
- Multiplayer is planned. The time source and the log store must sit behind small interfaces, so server time and a persistent database can replace them later without changing the rules above.

**Typed-in entries:**
- Today they count. Anti-cheat stays on the deferred list.
- Flagged typed-in entries (`HKMetadataKeyWasUserEntered`) are meant to be left out later. Build that as a switch, off for now. The flag is only set when the writing app sets it (ticket 01).

**Passed on:**
- `10`: the state log, the time-source interface, the typed-in switch, and sample-based timing in the sync path.

---
type: grilling
status: open
blocked-by: [01, 03]
claimed:
---

# Boost timing and anti-gaming

## Question

How do we stop "build or move workers after the workout, then sync" tricks? Known idea: compare the timestamp of a building or worker change with the workout completion timestamp. Fallback idea: a delay of about one hour before changes take effect.

Decide: which timestamp wins, what a change affects (past samples, future samples), whether the delay is needed at all, and what the user sees while a change is pending.

## Already decided (from ticket 03)

Each sync pays only the new ring progress since the last sync. Ring totals carry no times (see ticket 01). Skipped-day tracking uses the goal stored for that day and may be exploitable. Check that here.

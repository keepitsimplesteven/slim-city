---
type: grilling
status: closed
blocked-by: []
claimed: steven
---

# Scope and ground rules

## Question

What is the MVP, and which ground rules bind every ticket?

## Resolution

Settled during charting (rounds 1 to 3).

**Goal.** MVP spec = core gameplay loop plus stubs of advanced features.

**Code.** Current code is a draft. HealthKit integration and camera controls stay as is. Other parts, including frozen APIs, may change when a closed ticket decides it.

**Data, not code.** Buildings, costs, upgrades, caps, rates, ring-to-resource links are all configurable data.

**Earning is live.** Resources are credited as HealthKit syncs. No morning digest or single collect. A "Day" still exists, for daily caps.

**Resources.** Four: food (calories ring), wood (exercise ring), stone (stand ring), gold (steps). Ring-to-resource links are data. Gold may be phased out later.

**Per-ring yield.** Each ring gives up to 100 resources per day at 100% of its goal (a percentage of the ring filled). The cap is 1.5x the goal (150 resources), reset at local midnight. The multiplier is configurable. Exercise and stand goals can be changed by the user, so yield is a percentage of the goal, not a raw count.

**Buildings.** Each building has its own footprint, stored as data (for example house 2x2, village hall 3x3, lumber mill 2x3; specifics pending). Full list, all placeable: Village Hall, House, Farm, Lumber mill, Quarry, Bank (gold), Mission board, Marketplace (replaces the old Market; the multiplayer-style launch point), Records. Beyond the core loop, behavior is a stub.

**Editing.** An explicit "edit" mode, not free dragging. Moving is free. Deleting refunds all resources.

**People.** In the MVP. Houses give people. Boosts depend on where people are placed.

**Boost timing.** Changing worker placement applies to the next collection. If this can be gamed, add a delay of about one hour so HealthKit has time to sync. Enforcement compares the timestamp of the build/worker change with the workout completion timestamp.

## Not decided here

Everything in the map's open tickets and fog.

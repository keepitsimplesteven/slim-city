---
type: grilling
status: open
blocked-by: [02, 03]
claimed: steven
---

# Migration from current code

## Question

What changes in the existing code? Today it has a daily ledger, a claim step with a backfill cap, and 1x1 buildings. Decide, per part, whether it stays, changes or goes: `LedgerService`, `GameState`, `BuildingCatalog`, persistence models, the claim UI. Keep HealthKit and camera. Check the code against each decision.

## Already decided (from tickets 03 and 04)

Needs: a state log with times, a time-source interface and a log-store interface (for server time later), sample-based timing in the sync path, a typed-in switch, background delivery and its entitlement, and reading the Exercise and Stand goals.

## Added by ticket 12

Needs: build state (scaffold, ready, open), effort bars per source, a construction worker cap, a swappable fill rule chosen in data, the "!" open flow, and 4 stages of visuals per build.

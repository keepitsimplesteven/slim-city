---
type: grilling
status: closed
blocked-by: []
claimed: steven
---

# Building data model

## Question

What does one building definition hold, so everything stays data and easy to tweak? Decide the fields and their meaning: footprint (width, height), cost, cost growth for each extra copy, level and upgrade shape, what it produces or boosts, people it houses or needs, unlock level (Village Hall), art reference.

Constraint: no building is tied to a specific upgrade in code. Reuse or replace `BuildingDefinition` as this ticket decides.

## Resolution

Everything below is data in the building catalog. Nothing is tied to a specific building in code.

**Building definition (per type):**
- `id`, `displayName`, `modelName` (art key).
- `footprint`: width and height.
- `baseCost`: an amount for each of the four resources (zero allowed).
- `costGrowth`: each extra copy costs `baseCost x costGrowth^(copies owned)`. Starts at 1.2. A shared default exists, and each building can override it.
- `unlockLevel`: the Village Hall level needed. Values come from ticket 08.
- `effects`: the effects it has at the start.
- `workerCapacity`: how many people can be stationed here.
- `upgrades`: a list of upgrade nodes.
- Dropped: `score`. Add it back when a ticket needs it.

**Upgrade node:**
- `id`, `cost`, `effects`.
- Optional `needs` (upgrades to own first) and `blocks` (upgrades it shuts out). Usually both are empty. Different upgrades mostly differ by cost and effects, for example a house upgrade for +1 person or one for slower food drain.
- Levels are a chain of nodes, each needing the one before. There is no separate level table. Progress does not have to be a straight line.
- An upgrade can raise `workerCapacity`.

**Effect:**
- Kind: `add` (a flat amount) or `multiply` (a factor).
- Names a resource, or people, or capacity, or food drain.
- Optional flag `perPerson`: repeat once for each person stationed in this building, up to its capacity.
- Scope: this building only, or every building of the type.

**How effects combine for one resource:**
`total = (sum of all adds from all buildings) x (product of all multipliers from all buildings)`

Worked example. Farm A is level 1: +10 food, x1.1 per person, 1 person placed. Farm B is upgraded: +10 food, x1.2 per person, 2 people placed.
- Adds: 10 + 10 = 20.
- Multipliers: 1.1 x 1.2 x 1.2 = 1.584.
- Food = 20 x 1.584 = 31.68, before the daily cap.

**Ownership:**
- Each placed building owns its upgrades and its stationed people.
- A placed building stores: type id, position, upgrades owned, cost paid, and who is stationed.
- Deleting refunds the cost paid for that copy plus the cost of every upgrade on it. This follows the ground rule that deleting gives all resources back. The user's last answer did not cover refund of upgrades directly, so this is an assumption. Change it here if wrong.
- Because each copy has its own price paid, deleting one lowers the price of the next copy.

**Passed to other tickets:**
- `05`: how many people exist, where they come from, food drain, diminishing returns, and what the "per person" cap means for balance.
- `06`: how footprints fit on the grid, and edit mode.
- `08`: the Village Hall unlock table.
- `10`: how `BuildingDefinition`, `BuildingCatalog` and `PlacedBuilding` change to match this model.

**Clarified by the user after closing:**
- Price of the next copy always follows the formula from the number of copies owned. It does not depend on what was paid for older copies.
- Food is generally not a building cost. It feeds people. Build costs are mostly wood, stone and gold. The data still allows any of the four.
- Farms follow the same rules as every other building. The refund assumption above stands.

**Update from ticket 03:** the ring's base yield (100) is counted as one flat add. All adds, including building adds, are scaled by ring progress. See [Live earning model](03-live-earning-model.md) for the full formula.

**Update from ticket 06:** a placed building also stores its anchor cell and rotation. The effect scope list gains a reserved "neighbors" value that nothing evaluates yet.

**Update from ticket 08:** an upgrade node can require specific buildings to be owned, and can have effort bars (one target per source) instead of, or as well as, a resource cost. Ticket 12 decides how far effort bars reach.

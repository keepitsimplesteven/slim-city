---
type: grilling
status: closed
blocked-by: [02]
claimed: steven
---

# Village Hall levels and unlocks

## Question

What does each Village Hall level unlock? Notes say: larger build area, new buildings, maybe one ring of tiles per level. Decide: the level table (as data), its costs, which buildings unlock when, and what a new game looks like before the Hall exists.

## Resolution

**Structure.** The Village Hall is a normal building in the catalog (ticket 02), 3x3, one per city, not deletable (ticket 06). Its levels are a chain of upgrade nodes. Each level adds effects such as more people and a bigger grid. Every other building names the Hall level it needs. All numbers below are first guesses, and all are data, easy to change.

**Starter unlock list** (more is likely):

| Hall level | Buildings |
|---|---|
| 1 | House, Farm |
| 2 | Lumber mill, Quarry |
| 3 | Mission board |
| 4 | Marketplace, Bank |
| 5 | Records |

The Hall stops at level 5 in the first version.

**Grid.** Starts at 8x8 and adds one ring per Hall level, so level 5 is 16x16. Very tunable.

**Hall upgrade ("graduation").**
- To start an upgrade you must own one of each building unlocked at your current level (to leave level 1: a House and a Farm). The requirement is checked once, when you press upgrade. Deleting a building later does not stop the upgrade.
- The upgrade costs no resources. It has **effort bars**: one bar per source (food/Move, wood/Exercise, stone/Stand, gold/Steps). Each bar has its own target, measured in progress at base rates (before building bonuses) and counted up to each day's cap.
- Bars add up and never decay. Skipping a day just slows them. Only one Hall upgrade runs at a time. It cannot be cancelled.
- Placeholder targets: 2 daily goals of each source per level. Data, per level.
- It runs next to normal earnings. The same exercise both pays resources and fills the bars.
- The top level has no upgrade.

**New game.**
- The grid is empty. The only building available is the Village Hall, and it is free. It gives a few people (ticket 05).
- Nothing is tracked until the Hall is placed. Exercise done before that does not count. After that, the app tells the player to go exercise and come back.
- A tutorial needs its own tickets (new fog).

**Open question handed to ticket 12.** The user wants to consider effort bars for all buildings: place a scaffold that costs resources, fill effort bars, and the building completes at the next login. That also raises what happens to idle and excess resources. Ticket 12 decides it. This ticket's Hall rules assume effort bars exist and may change with ticket 12.

**Passed on:**
- `02`: an upgrade can require specific buildings and can have effort bars instead of a resource cost.
- `09`: Mission board unlocks at level 3, Marketplace at 4, Records at 5.
- `10`: effort bars need their own saved progress per source.

**Update from ticket 12:** the Hall upgrade now runs on the shared effort rule. It has an effort target per source set directly in data and no resource cost, a worker count that speeds the fill, and the "!" tap to open. It no longer needs a separate mechanism. Carpentry joins the unlock list (level set in ticket 11).

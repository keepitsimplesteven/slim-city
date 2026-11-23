---
type: grilling
status: closed
blocked-by: []
claimed: steven
---

# Construction effort (scaffolding)

## Question

Should buildings and upgrades need effort as well as resources? The idea from ticket 08: place a scaffold that costs resources (for example 50 wood and 500 gold). Then fill effort bars (for example 5,000 steps and half the exercise goal at base rates). The building finishes the next time the player logs in. The Village Hall upgrade already uses effort bars, with no resource cost.

Decide:
1. Which things use effort: only Hall upgrades, all buildings, or all buildings and all upgrades.
2. What a scaffold is on the grid (footprint reserved, can it be moved or deleted, refund).
3. When it finishes ("next login" or the moment bars fill) and who sees it.
4. What happens to idle and excess resources, since resources would no longer be the only gate. Does the same exercise both pay resources and fill bars?
5. Whether one build can run at a time or several.
6. How this fits the state log (ticket 04) and the data model (ticket 02).

## Resolution

**Rule for the MVP.** Every new building and every upgrade needs effort as well as resources. All resource use needs additional effort. The Village Hall needs much more effort than other buildings. Only the rule below ships in the MVP.

**Paying.** The resource cost is paid when the scaffold is placed (ticket 02 costs). Cancel returns all of it.

**Effort bars.**
- A build has one bar for each resource in its cost. Wood fills from the Exercise ring, stone from Stand, food from Move, gold from steps.
- Bars fill from ring progress, counted at base rates before building bonuses (ticket 08), up to each day's cap.
- Each bar fills in proportion to the collection rate as the matching ring closes, times the workers on the build.
- A bar's target is its own data value. By default it is the cost times a ratio. It can be set directly, which is how the Hall asks for effort with no resource cost (ticket 08).
- The same exercise both pays resources and fills bars. Bonuses make you rich, not fast.

**Workers.**
- Each worker adds a flat amount of fill speed. Each extra worker adds less (a curve in data). With zero workers, nothing fills.
- A scaffold has no worker limit of its own. All construction workers may sit on one build.
- The limit is the total number of construction workers you can have (see the update at the end: the Hall gives 1, the Workshop adds more). It is a cap on people from the same pool as ticket 05, so putting people on construction means fewer on production.
- A new **Carpentry** building raises that total. It is a normal building in the catalog (footprint, cost, unlock level, upgrades). Its Hall level and numbers come from ticket 11. Added to the map's unlock list.
- Worker moves go in the state log with a time (ticket 04). Fill uses the worker count at the time the exercise started.

**Scaffold on the grid.** Takes the full footprint at once. Can be moved and rotated (ticket 06). No effects, no production workers. Several builds can run at the same time, if each has at least one worker.

**Cancel or delete.** Resources come back. All effort is lost, and the next build has to gather it again. The app warns about this before it cancels.

**Opening.**
- When all bars are full, the workers go free and an "!" shows on the building.
- The player taps it to open it, like a ribbon cutting. Effects start at that tap. Until then it earns and boosts nothing.
- Each build and upgrade shows 4 stages, at 25%, 50%, 75% and 100% of its progress. A shared scaffold look is the default. Special art comes later.

**Swappable.** What fills a build is one replaceable piece, chosen in data. Ideas kept for later play tests:
- Steps as the effort for everything, with workers speeding the rate. Gold might then drop out or double up.
- Taking the cost from the stockpile bit by bit as you exercise, with workers speeding the draw.

Neither is built in the MVP. They are listed in ticket 11.

**Passed on:**
- `11`: Carpentry numbers and unlock level, the worker curve, effort ratios, Hall effort targets, and play tests of the two swap ideas.
- `10`: build state (scaffold, ready, open), bar progress per source, a worker cap, the "!" flow, and the swappable fill rule.
- `08`: update the Hall to use this rule.

## Update after closing: construction worker cap

- The construction worker cap is set by buildings, not by a loose number. The Village Hall gives 1. A level 1 Carpentry building (working name below) adds a second. Upgrading it adds a third, and so on. All amounts are data.
- A person is still needed for each construction worker, so the cap only matters if there are enough people (ticket 05). A cap of 3 with 2 people means 2 workers.
- Name: "Carpenter's Workshop", short name "Workshop". Not final.

## Amended by ticket 14 (round 2)

Effort is not a visible metric. The player sees, per cost resource, "x of y gathered" and the real-life work left. A builder assembles at 2x the gathering rate (data). Worker count changes the time left.

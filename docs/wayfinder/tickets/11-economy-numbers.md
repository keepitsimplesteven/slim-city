---
type: prototype
status: closed
blocked-by: []
claimed: steven
---

# Economy numbers

## Question

Do the starting costs, rates and caps feel right? Build a cheap throwaway sim (script or sheet) that plays a few weeks of rings against the data model. Check: how long to the first house, whether people stay the bottleneck, and whether the cap bites. Link the prototype from this ticket.

## Added by ticket 12

Also tune: Carpentry unlock level and effect, the construction worker curve, effort ratios, Hall effort targets. Play-test two alternatives to the MVP effort rule: (1) steps as the effort for everything, workers speed it, gold maybe dropped or doubled; (2) cost drawn from the stockpile bit by bit as you exercise, workers speed the draw.

## Rounds 1 and 2

Sim: `prototypes/11-economy/` (`sim.py`, `data.json`, `README.md`, `round1-output.txt`). Decisions so far: four player types, three starter plans, Python plus one JSON data file, ring share past 100% as a switch (half rate to 200%, off by default). Ticket stays open for tuning.

## Resolution

Closed with the numbers in `prototypes/11-economy/data.json` as a **starting point**. Steven will tune them in play tests. The file is meant to become the real data file.

- **Bases per full ring:** food 100, wood 30, stone 12, gold 100 (100 steps per gold, 10,000 steps a day).
- **Ring cap:** 1.5. A switch for half rate up to 200% exists in the data, off by default (stretch goal).
- **Variance:** rings vary per day around a player's average. A `perfect` persona closes every ring every day.
- **Food:** 24 per person per day in the sim. Rescue behavior is stock: farms get workers first and only farms start while food is short.
- **Side work:** a build needs a free construction worker. The Hall gets workers first. The Carpenter is what allows side work.
- **Starting wallet:** wood 30, gold 100. That pays for the Hall and one house.
- **Hall:** 3 days of effort at level 2 for a normal player, then double each level.

## Findings to carry on
- Hall pace is the gate. Normal players reach Hall 2 on day 8, Hall 3 on day 18 to 20. Nobody reaches Hall 5 in 28 days.
- Food is what stops a light (50%) player.
- Gold piles up even at 100 a day. Gold costs and a use for gold are still open (fog: gold exchange).
- Carpenter unlock level and numbers are placeholders (level 2).
- Eating is once a day in the sim. The real game eats at intervals (ticket 15).
- Not tested: steps as effort, and the stockpile-draw rule from ticket 12. Both stay as written alternatives.

---
type: prototype
status: open
blocked-by: []
claimed: steven
---

# Economy numbers

## Question

Do the starting costs, rates and caps feel right? Build a cheap throwaway sim (script or sheet) that plays a few weeks of rings against the data model. Check: how long to the first house, whether people stay the bottleneck, and whether the cap bites. Link the prototype from this ticket.

## Added by ticket 12

Also tune: Carpentry unlock level and effect, the construction worker curve, effort ratios, Hall effort targets. Play-test two alternatives to the MVP effort rule: (1) steps as the effort for everything, workers speed it, gold maybe dropped or doubled; (2) cost drawn from the stockpile bit by bit as you exercise, workers speed the draw.

## Round 1 (in progress)

Sim: `prototypes/11-economy/` (`sim.py`, `data.json`, `README.md`, `round1-output.txt`). Decisions so far: four player types, three starter plans, Python plus one JSON data file, ring share past 100% as a switch (half rate to 200%, off by default). Ticket stays open for tuning.

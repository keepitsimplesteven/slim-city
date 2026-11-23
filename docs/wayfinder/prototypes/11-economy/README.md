# Economy sim, round 1 (throwaway)

Run: `python3 sim.py` (table) or `python3 sim.py --daily normal builder` (day by day).
All numbers live in `data.json`. Output of round 1: `round1-output.txt`.

## What it models
- Players close rings at a fixed share each day: light 0.5, normal 1.0, hard 1.5, extreme 2.0.
- Pay: `(base + building adds) x progress x worker multipliers`. Progress is capped at 1.5 (or the half-rate overflow, `overflow.enabled`, up to 200%).
- A scaffold pays its cost up front. Each cost resource then has a bar. Bar fill per day = base x progress x 2 x worker curve. Bars ignore building adds and multipliers.
- Hall upgrades cost no resources. Their bars use the `hall.effort` numbers.
- Construction workers: 1 from the start, +1 per Carpenter. They come out of the same people pool.
- Templates are ordered move lists in `data.json`. A step waits until it is unlocked and affordable.
- A scaffold placed at the start of a day gets that day's progress. A finished build opens at the start of the next day.

## Round 1 reading (normal player, 28 days)
- The Hall bars are the gate. Most blocked days are "locked", waiting on the next Hall level. The Hall reaches level 4 around day 8 and level 5 is not reached by the economy plan.
- Gold piles up: 25,000+ unspent at the end. Base 1,000 a day against costs of 300 to 900 makes gold close to free.
- Wood, stone and food stay small next to gold. Wood is the only resource that ever blocks a placement.
- Food bites hard for a light player. With 12 people eating 24 a day each, a half ring does not cover it, so 26 of 28 days are hungry.
- A normal player is hungry on 16 days with the builder plan and 0 on the others. The builder plan has more houses than farms.
- The cap never bites below the hard player. Extreme players are capped on all 28 days.
- Idle construction workers are rare. People are the bottleneck only for the builder plan.

## Caveats
- Day steps, not hours. Food is eaten once a day here, not at intervals.
- Costs and effort are my guesses. This round shows shape, not final numbers.
- The sim places builds at day start with perfect play. Real players will be slower.

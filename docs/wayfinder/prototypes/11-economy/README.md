# Economy sim, round 1 (throwaway)

Run: `python3 sim.py` (table over 30 seeds) or `python3 sim.py --log normal builder 5` (day-by-day log of one run, seed 1).
All numbers live in `data.json`. Round 1 output: `round1-output.txt`. Round 2: `round2-output.txt` and `round2-log-normal-builder.txt`.

## What it models
- Players close rings at a fixed share each day: light 0.5, normal 1.0, hard 1.5, extreme 2.0.
- Pay: `(base + building adds) x progress x worker multipliers`. Progress is capped at 1.5 (or the half-rate overflow, `overflow.enabled`, up to 200%).
- A scaffold pays its cost up front. Each cost resource then has a bar. Bar fill per day = base x progress x 2 x worker curve. Bars ignore building adds and multipliers.
- Hall upgrades cost no resources. Their bars use the `hall.effort` numbers.
- Construction workers: 1 from the start, +1 per Carpenter. They come out of the same people pool.
- Templates are ordered move lists in `data.json`. A step waits until it is unlocked and affordable.
- A scaffold placed at the start of a day gets that day's progress. A finished build opens at the start of the next day.

## Round 1 reading (normal player, 28 days)
- The Hall bars are the gate. Most blocked days are "locked", waiting on the next Hall level. A normal player with the builder plan reaches Hall 2 on day 8, Hall 3 on day 16 and Hall 4 on day 26. Nobody reaches Hall 5 in 28 days.
- Gold piles up: 25,000+ unspent at the end. Base 1,000 a day against costs of 300 to 900 makes gold close to free.
- Wood, stone and food stay small next to gold. Wood is the only resource that ever blocks a placement.
- Food bites hard for a light player. With 12 people eating 24 a day each, a half ring does not cover it, so 26 of 28 days are hungry.
- A normal player is hungry on 16 days with the builder plan and 0 on the others. The builder plan has more houses than farms.
- The cap never bites for light, normal or hard players. The extreme player (200%) is capped on all 28 days.
- Idle construction workers are rare. People are the bottleneck only for the builder plan.

## Caveats
- Day steps, not hours. Food is eaten once a day here, not at intervals.
- Costs and effort are my guesses. This round shows shape, not final numbers.
- The sim places builds at day start with perfect play. Real players will be slower.

## Round 2 changes
- Bases are now food 100, wood 30, stone 12, gold 100 per full ring. Costs and Hall effort were scaled to match, so they are rough.
- Each ring varies per day around the player's average (sd 0.25), so a 50% player might do 75% move, 25% exercise. Results average 30 seeds. A `perfect` persona closes every ring at 100% every day, with no variance.
- Plans are priority lists. Each day the sim tries every step in order and skips locked ones. A step short on resources holds back the later steps.
- Side work: a new scaffold only starts if there is a construction worker for it (`limit_scaffolds_to_workers`). The Hall upgrade gets workers first, then other scaffolds get one each. With one construction worker, only the Hall moves. A Carpenter adds side work.
- Food rescue (stock behavior, `food_rescue` in the data): when food is under one day of eating, or the last day went hungry, farms get workers first, no new builds start except farms (up to 4), and the rest of the workers get what is left.

## Round 2 reading
- Perfect and normal players reach Hall 2 on day 7 to 8 and Hall 3 on day 15 to 20. A light player (50%) reaches Hall 2 only on day 18 to 20, and only some seeds make it.
- A light player is short on food on 5 to 7 days and in rescue on 14 to 19 days. Food is the thing that stops a light player.
- Gold still piles up (2,500 at the end for a normal player), even at 100 a day. Costs in gold are small. Next: either raise gold costs or cut the Bank/gold use.
- With one construction worker, side work barely happens. The Carpenter is the unlock for building while the Hall builds.

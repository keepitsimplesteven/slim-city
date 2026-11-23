---
type: grilling
status: closed
blocked-by: [01, 03]
claimed: steven
---

# Gold, steps and the Bank

## Question

How does gold work? Steps are the proxy. Decide: how steps map to gold, the cap, what the Bank does (boost, store, or both), what gold buys, and how easy it is to phase gold out later.

## Resolution

**Gold earns like the other resources.** `gold = (base + adds) x min(progress, cap) x multipliers` (ticket 03).

**Per-resource data.** Each resource has its own `base`, its own `source`, and its own `goal`. Defaults:

| Resource | Source | Goal | Base |
|---|---|---|---|
| Food | Move ring | HealthKit goal | 100 |
| Wood | Exercise ring | HealthKit goal | 100 |
| Stone | Stand ring | HealthKit goal | 100 |
| Gold | Steps | 10,000 steps, fixed in data | 1,000 |

- Gold base 1,000 at 10,000 steps means 10 steps per gold. All four values can be changed in data, so a step goal setting can be added later.
- The step goal is fixed per day in the same way as the ring goals (ticket 03).
- Progress is steps today divided by the goal. The total comes from HealthKit's daily sum, which removes phone and watch duplicates. Step samples give the times (ticket 04).

**Bank:** works like the Farm, Lumber mill and Quarry, but for gold. Flat adds, plus per-person multipliers.

**No storage cap.** The daily cap is the only limit. A cap can be added later as data.

**Gold buys what the others buy.** It is one of the four costs on buildings and upgrades. There is no gold-only use in the first version.

**No on/off switch for resources.** Gold is always on. Each resource keeps its source and goal as data, which is enough for other trackers later.

**Passed on:**
- `11`: base values (gold 1,000, others 100).
- `10`: steps need their own progress source in the sync path, with a data goal.
- New fog: gold exchange (see map).

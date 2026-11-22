---
type: grilling
status: closed
blocked-by: [02, 03]
claimed: steven
---

# People, workers and food

## Question

How do people work in a live-earning game? Decide: how houses make people, how people are placed in buildings, how placement boosts output (stars, diminishing returns, or N people to unlock a level), whether people eat and when, and whether placement changes apply to the next sync only.

Food shortage ("ration") is fog until this closes.

## Already decided (from ticket 02)

Each building has its own worker capacity, which upgrades can raise. A "per person" effect repeats once for each person stationed, up to that capacity. Multipliers from all buildings multiply together. This ticket decides the rest: where people come from, food drain, diminishing returns, and balance.

## Resolution

**People:**
- Each house adds people through a data effect. A house upgrade can add more.
- The Village Hall gives a few people at the start so the first buildings can work. The numbers are data and get tuned in ticket 11.
- A person appears the moment the house is built.

**Placing:**
- Each person is in one building or free. You add or remove people at a building, up to its capacity.
- Capacity is the only limit on workers. There is no diminishing curve. Capacity is data and upgrades can raise it.
- Flat adds need no people. Only "per person" multipliers need people stationed.
- Moving people is free. It affects only later exercise (ticket 04) and goes in the state log with a time.

**Food:**
- Everyone eats once a day at the midnight reset, free people too: `food taken = people x food rate`, reduced by any "slower drain" upgrades.
- Rate is data. A separate data value for free people (default: same rate) lets you tune this later.
- The amount comes out of the food you hold.

**Shortage:**
- If food cannot cover it at reset, the app warns the player. They get one day to bring food up. Food does not go below 0.
- The punishment after the grace day is not decided yet. Build a hook for it, switched off in the data. Do not guess a penalty. Stays in the fog.

**Deleting a house:**
- Its people vanish. If that leaves fewer people than are placed, the people most recently placed are freed first. The change goes in the log with a time.

**Passed on:**
- `11`: starting people, food rate, grace rule, house numbers.
- `10`: state log entries for people, the midnight food step, the shortage hook.

## Amended by ticket 15

Food is eaten at regular intervals through the day, not once at midnight. The interval is data. Daily total is unchanged. Shortage warning and grace day stay. Ticket 11 sets the interval.

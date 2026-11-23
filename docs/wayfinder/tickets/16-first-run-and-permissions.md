---
type: grilling
status: closed
blocked-by: []
claimed: steven
---

# First run and permissions

## Question

What happens from install to a placed Village Hall scaffold? Decide: the HealthKit permission ask (what we say, which types we request), what the app does if the player says no or has no data, the starting wallet, people and worker cap (ticket 10), how the Hall scaffold is placed, and when tracking starts (ticket 08).

Also decide how a returning player with a wiped save is treated, and whether the first screen needs an intro.

## Resolution

Decided with Steven (Q1-Q8).

- **Intro (Q1, Q8):** one screen, no skip, once per install. It says all Health data is READ ONLY and nothing is written. One button: "Allow Health access". Apple's sheet follows.
- **Data asked (Q2):** read only. Activity summary (rings and goals), workouts, active energy, exercise minutes, stand hours, step count.
- **No Health access (Q3, Q4, changed):** the game is inoperable. HealthKit cannot say "denied", so the app treats "no data after the ask" as blocked. It shows a blocking screen: "Slim City needs Health access. Check Settings > Health > Slim City". It re-checks on return to the app. Debug builds may use the fake feed from ticket 10.
- **First run (Q5, changed):** intro, Health ask, empty grid with a ghost Village Hall, Confirm places it. Tracking starts at placement, but today's progress so far is paid retroactively (today only). Nobody who closed their rings before installing is locked out.
- **Onboarding is data (Q5):** the whole first run is an ordered script in data: steps, text, starting wallet, people, workers, how many past days pay, and whether the Hall starts ready to cut. Default: retroactive today, Hall is a normal scaffold. Written alternative: the Hall starts with its ribbon ready to cut, and the wallet covers a first house. Swapping is a data change.
- **Returning player (Q6):** same as new. The Health ask is skipped if the system already has an answer. The retroactive window is the same data value.
- **Notifications (Q7):** asked once, after the first scaffold is placed, in the drawer. No second ask.

## Amends

- Ticket 08 and 10: "nothing counts before the Hall is placed" becomes "tracking starts at placement, with a data value for how many past days pay (default: today only)".
- Ticket 04: the retroactive payout is priced at the state at placement, since no buildings existed earlier.

## Verification

Health prompts, the blocked screen and the retroactive payout need a device. They cannot be checked headlessly.

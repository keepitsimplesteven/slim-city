# Map: Slim City MVP

Label: `wayfinder:map`. Tracker: local markdown. Tickets are files in `tickets/`.

## Destination

A Kiro spec (`requirements.md`, `design.md`, `tasks.md`) for the MVP: the core live-earning gameplay loop plus empty stubs for the advanced features. Reached when no open ticket remains and the fog is cleared or ruled out.

## Notes

- Raw brainstorm, verbatim: [NOTES.md](NOTES.md). Never edit it. Quote it from tickets.
- Rule for every ticket: buildings, costs, upgrades, caps, rates, resource-to-ring links, and delays are **data, not code**. Easy to tweak during development.
- Stable, leave alone: HealthKit integration, camera controls (pan/zoom). Everything else is a draft and may change when a closed ticket says so, including the frozen APIs in `.kiro/steering/slim-city-constraints.md`.
- Skills for HITL tickets: `grilling`, `domain-modeling`. Research tickets: `research`. Prototype tickets: `prototype`.
- Ticket format: front matter with `type`, `status` (open/closed), `blocked-by`, `claimed`. Frontier = open, unclaimed, every `blocked-by` closed.
- Find the frontier: `grep -L 'status: closed' docs/wayfinder/tickets/*.md`
- Spec feed: Destination + Decisions so far -> `requirements.md`. Closed tickets -> `design.md`. `tasks.md` is written last.

## Decisions so far

- [Scope and ground rules](tickets/00-scope-and-ground-rules.md): MVP is the live-earning loop, four resources, per-building footprints, edit mode with full refund on delete, all buildings placeable with later ones as stubs.

- [HealthKit capabilities](tickets/01-healthkit-capabilities.md): goals, sample timestamps, steps and user-entered flags are readable. No awards API. Delivery is not truly live (hourly at best), and background delivery is not set up in the app yet.

- [Building data model](tickets/02-building-data-model.md): one catalog of data. Each placed building owns its upgrades and people. Effects either add or multiply, and add x multiply gives the total. Costs grow by 1.2x per copy, tunable.
- [Live earning model](tickets/03-live-earning-model.md): earned = (base + adds) x min(progress, 1.5) x multipliers. Each sync pays only new progress. The day's goal is fixed at the start of the day. Midnight local reset. 7-day catch-up.
- [Boost timing and anti-gaming](tickets/04-boost-timing.md): exercise is paid at the building state when it started. A timed log of changes (7 days) answers that. No delay. Phone clock for now, behind an interface so server time can replace it. Typed-in entries pass for now, with a switch.
- [People, workers and food](tickets/05-people-workers-food.md): houses add people, people are placed up to each building's capacity, everyone eats at midnight, a shortage warns and gives one day of grace. Deleting a house frees the most recently placed people.
- [Grid, footprints and edit mode](tickets/06-grid-and-edit-mode.md): buildings rotate in quarter turns. Place by tap, preview, rotate, confirm. Edit mode for move, rotate, delete. One Village Hall, not deletable. Grid grows by a ring on every side, positions stored from the center. Neighbor bonuses are a reserved, unused slot.
- [Gold, steps and the Bank](tickets/07-gold-and-bank.md): gold earns by the same formula. Source is steps, goal 10,000 fixed in data, base 1,000 (10 steps per gold). The Bank works like the other producers. No storage cap. Each resource has its own base, source and goal in data.
- [Village Hall levels and unlocks](tickets/08-village-hall.md): the Hall is a normal building with 5 levels. Starter unlock list is data. Grid 8x8 plus a ring per level. A Hall upgrade needs one of each current-level building, no resource cost, and fills one effort bar per source. New game: only a free Hall, and nothing is tracked until it is placed.

## Open tickets (index only; detail lives in each file)

| Ticket | Type | Blocked by |
|---|---|---|
| [Construction effort (scaffolding)](tickets/12-construction-effort.md) | grilling (HITL) | none |
| [Stub contract](tickets/09-stub-contract.md) | grilling (HITL) | none |
| [Migration from current code](tickets/10-migration-from-current-code.md) | grilling (HITL) | 03, 02 |
| [Economy numbers](tickets/11-economy-numbers.md) | prototype (HITL) | 12 |

## Not yet specified

- Food shortage punishment: what happens after the grace day. A switched-off hook exists. Hangs on Economy numbers.
- Tutorial and first-run flow: needs its own tickets. Hangs on Screens and flows.
- The chase: what happens when everything is built. Perfect weeks, perfect year, special buildings. Hangs on Economy numbers.
- Medals: HealthKit cannot read watch badges (confirmed), so they must be built in. Rewards are out of scope for now.
- Screens and flows: build list, building card, edit mode controls, warnings, onboarding. Needs its own tickets. Hangs on all the closed ones.
- Neighbor bonuses: a building that boosts nearby ones, or bonuses for touching groups. Reserved slot only, not MVP.
- Gold exchange: buying other resources with gold at a steep price, possibly a building with upgrades. Hangs on Economy numbers.
- Art: Kenney assets at a 2x2 sub-grid per tile. Hangs on Grid and footprints.
- Mission board content. Hangs on Stub contract.

## Out of scope

- Real networking: visiting villages, alliances, shared goals, requesting wood. Marketplace is a stub only.
- Bot trading partner.
- Quest and bounty content, randomized tasks.
- Medal rewards and reskins.
- Records content (statistics, milestones).
- The "pledge and lock your day" gameplay loop. Replaced by live earning.
- Passive/idle tick production. Earning is driven by HealthKit, not time.

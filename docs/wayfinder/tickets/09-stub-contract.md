---
type: grilling
status: closed
blocked-by: [02]
claimed: steven
---

# Stub contract

## Question

What is the minimum a stub building does? Covers Mission board, Marketplace, Records. Decide: can it be placed and deleted, does it open a screen, what does that screen say, and what interface it exposes so the real feature can drop in later without reshaping the data model.

## Resolution

**A stub is a normal building.** It is a catalog entry with a footprint, cost, unlock level, upgrades and people, like any other (ticket 02). There is no special stub code. It can be placed, moved, rotated and deleted. Delete refunds in full (ticket 02). Starter stubs: Mission board (Hall 3), Marketplace (Hall 4), Records (Hall 5), per ticket 08.

**No effects.** A stub has no boosts and no effects until its feature is built. The starter data gives them none. The data model would allow effects, but none are set.

**Tapping one outside edit mode:** opens one shared screen with the building's name, a short "coming soon" line, and the usual building card (upgrades, people).

**Plugging a feature in later:**
- A building definition can name a `featureId` in data, for example `missions`.
- The app keeps a registry of features. If a feature is registered under that id, tapping opens it. If not, the shared stub screen opens.
- Adding a feature means registering it. The building data and the saved game do not change shape.

**Feature data:**
- Each feature owns its own saved data under its `featureId`, apart from the city.
- A stub saves nothing.
- **Deleting a building erases its feature data. Rebuilding starts fresh and un-upgraded.** (Changed from my first proposal, by the user.)
- Scope of that rule: it covers data kept for the building. Village-wide totals, such as Records statistics, are not kept per building. They should come from the state log and the ledger, so they survive a delete. Decide this when Records is built.

**Other switched-off hooks.** The food penalty (ticket 05), neighbor bonuses (ticket 06) and the typed-in entry switch (ticket 04) each stay a named setting in the data, set to off. No placeholder screens. Each gets a map line saying what turns it on.

**Passed on:**
- `10`: `featureId` on building definitions, a feature registry, per-feature saved data that is erased on delete, the shared stub screen.

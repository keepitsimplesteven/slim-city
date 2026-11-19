---
type: grilling
status: closed
blocked-by: [02]
claimed: steven
---

# Grid, footprints and edit mode

## Question

How does placement work with mixed footprints? Decide: grid size and growth, overlap and edge rules, rotation (yes or no), the edit-mode flow (enter, move, delete with full refund, exit), and how the existing 1x1 placement and render code adapts. Moving is free. Camera pan and zoom stay as they are.

## Resolution

**Footprint and rotation:**
- Each building has a footprint (width x height) in data.
- Buildings rotate in quarter turns. A quarter turn swaps width and height, so a 2x3 mill becomes 3x2.
- A placed building stores its anchor cell and its rotation.

**Grid:**
- The start size and each growth step are data in the Village Hall table (ticket 08). Growth adds a ring on every side.
- Cell positions are stored from the center, with negative numbers allowed, so growing never moves a building.

**Placing:**
- Pick a building from the build list. Tap a cell. A preview shows the whole footprint, tinted green or red. Tap another cell to move it. Rotate controls turn it. Confirm or Cancel ends it.
- The preview is not dragged, so one-finger pan stays free.

**Rules:**
- Every cell of the footprint must be on the grid and empty.
- There is only one Village Hall. It can be moved but not deleted, because everything else depends on it.
- Other buildings have no count limit. The rising price is the limit.

**Edit mode:**
- A button turns it on. Tap a building to pick it, then Move, Rotate or Delete. Move uses the same preview and Confirm step. Delete refunds at once and in full (ticket 02). Moving is free.
- Outside edit mode, tapping a building opens its card for upgrades and people.

**Neighbor bonuses (stubbed, not MVP):**
- Planned later: a building that boosts the ones around it, or a bonus when certain buildings touch (for example 3 or more houses touching).
- For now, position affects only looks. Reserve a "neighbors" value in the effect scope list (ticket 02) that nothing evaluates yet.
- Moves and rotations still go in the state log with a time (ticket 04). This is cheap, and it means neighbor bonuses can pay at the right state later.

**Passed on:**
- `08`: grid start size and growth.
- `10`: occupancy checks across a footprint, anchor and rotation on placed buildings, center-based coordinates, and the Village Hall rules.
- New fog: screens and flows (see map).

---
type: prototype
status: open
blocked-by: []
claimed: steven
---

# Build list, building card and construction UI

## Question

How should placing, editing and constructing feel on a phone? Make a cheap rough prototype (sketches or a throwaway screen) to react to. Cover: the build list (locked and unlocked buildings, cost, effort), the placement preview with rotate and confirm, edit mode, the building card, the scaffold card (one bar per resource, workers, cancel with its warning), and the "!" ribbon-cut open.

Link the prototype from this ticket. The rules are already decided in tickets 02, 06 and 12. This ticket decides layout and feel.

## Added by ticket 13

The user decides the final look and feel hands-on. Prototype in rounds with the user reacting. Also try: building sheet Edit button vs footer Edit mode (keep one or both), the build carousel with locks, several badges on one building, always-on progress rings, the header with people (for example `8/10`), the dialog box, and the bottom drawer.

## Round 1

Throwaway click prototype: [prototypes/14-round1.html](../prototypes/14-round1.html). Open it in a phone-width browser. It is plain HTML, not the app. Styling is placeholder and all colors sit in CSS variables at the top.

Covers: header with popovers and sync icon, city grid, per-building badges and rings, Build carousel with locks, placement preview with rotate and confirm, edit mode (footer and per-building button, both switchable), scaffold sheet with bars, workers and cancel warning, the "!" ribbon cut, stub sheet, collected modal, day ledger modal, dialog box, bottom drawer.

Not checked in a browser by the agent. Awaiting the user's reactions.

## Round 2

Prototype: [prototypes/14-round2.html](../prototypes/14-round2.html). Round 1 stays for comparison. Checked by script in a test DOM only (taps, sheets, edit lock, popovers); not looked at in a browser by the agent.

**User reactions to round 1, now in the prototype:**
- "Effort" is not shown anywhere. A builder assembles at 2x the gathering rate, so a 100 wood build fills like gaining 50 wood (base numbers, before modifiers). The scaffold panel shows a ring per resource with "x of y wood" and the real-life work left (for example exercise minutes, stand hours, move kcal, steps). Changing workers updates that number. The build list no longer shows effort.
- Scaffold panel uses rings, not bars.
- While one building is being edited, other buildings cannot be selected. The footer shows only Rotate and Done (plus a small delete). "Move" is gone: tap a cell to move the footprint.
- Each building shows worker heads (one per assigned worker).
- Open building panel has Edit and Upgrade buttons. Upgrade shows a menu of choices in the panel (Farm: Wagons = x per worker, Granary = + daily yield). The upgrade menu needs its own post-MVP ticket.
- Resource popover reads "x collected today / y% remaining". At the cap it shows gold text and "Daily max reached". No base-rate line for now, to test if hidden amounts feel too arcane.
- People popover (not a panel): "Consumes 13 food / hour, Free: 2 (1 food / hour), Working: 6 (12 food / hour)".
- Collected modal: no build bars. Capped resources in gold with "daily max reached". Food eaten shown here. Shows time since last collected.
- Day ledger dropped. The collected modal replaces it (changes ticket 15).

**Notes for 3D (not in the 2D prototype):**
- The "!" hovers above the building. Rings float on the building.
- Open question: should rings use the watchOS concentric style? Try in a later round.
- Rotate and confirm sit on the building: arrows on each side, check mark in the middle. No bottom bar.

**Open for round 3:** where Delete lives during edit (small button in the footer now); how many builders a build may hold (3 in the prototype).

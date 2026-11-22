---
type: grilling
status: closed
blocked-by: []
claimed: steven
---

# Screen inventory and navigation

## Question

Which screens does the MVP have, and how does the player move between them? Start from what the closed tickets already imply: the city view, a build list, a building card (upgrades, people), edit mode, a scaffold card (bars, workers, cancel), the "!" open moment, warnings (food shortage), debug, and a read-only Watch glance.

Decide: the full list of screens, what is always on the main screen, how each screen opens and closes, and which ones can wait until after the MVP. Camera pan and zoom stay as they are.

## Resolution

**Scope of this ticket.** It fixes which interactive elements exist and where they sit. It does not fix the look. The user wants strong hands-on control of the final look and feel, so visuals are decided in ticket 14 by prototype, with the user reacting. The spec must describe slots and behavior, not styling.

**Navigation.**
- The city is the home view. Other screens are sheets or drawers over it. No tab bar.
- This is not a firm boundary. Later features may take over the screen or change the main view. Example: an "other people's towns" view you move to, to see what friends built. Keep navigation behind one small router so a full-screen mode can be added without reshaping the city screen.

**City screen layout.**
- **Header:** the resources, plus people (for example `8/10` with a person icon, like an RTS: used / total). Food, wood, stone, gold, people.
- **Footer:** gameplay actions: Build, Edit. More can be added.
- **Corner:** the Debug button as a small floating button, debug builds only, as now.
- **On buildings:** badges and progress rings (below).

**Badges.**
- A building can show several badges at once.
- Known: "!" ready to open. Planned examples: "?" for quests or story, "not enough workers", "not enough food".
- Badges are data-driven: each has an id, an icon, a priority and a reason text. Tapping one opens the building sheet to the matching part. The full set is not decided now.
- **Progress rings** show on a building the whole time it is under construction, one per resource, without tapping.

**Build.**
- Tapping Build opens a carousel (ribbon) of buildings at the bottom. Locked ones stay visible with a lock and the requirement (the Hall level).
- A later expand option shows all buildings in a grid, using more or all of the screen. Not MVP.

**Building sheet.** One sheet, with a body per state: scaffold (bars, workers, cancel), ready (open button), open (upgrades, people, effects), stub ("coming soon" plus the usual card). It also holds an **Edit** button for that building, which starts edit mode for it. The user may drop the separate footer Edit mode, or keep both. This is a switch to try in the prototype (ticket 14), and the rules in ticket 06 hold either way.

**People.**
- Totals show in the header. A building sheet has a plus and a minus per building. Each person is assigned one at a time. No drag and drop.

**Other elements to plan for now.**
- A **dialog box** for characters or story. No content or plan yet. It is a reusable element that shows text, an optional portrait and a tap to continue.
- A **bottom drawer** that rises to about half or two thirds of the screen. Any information not yet planned goes here as a placeholder.
- Warnings use a banner or the drawer (ticket 15 decides).

**After the MVP.** Watch glance, Records, Marketplace and Mission board content, settings, history and stats, other people's towns.

**Passed on:**
- `14`: look and feel by prototype. User in the loop. Include the Edit button question.
- `15`: header contents, badges, banner and warnings.
- `16`: first run flow in this layout.
- `10`: a router for screens, a badge system, a dialog element and a drawer element.

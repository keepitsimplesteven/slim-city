---
type: grilling
status: closed
blocked-by: []
claimed: steven
---

# Guidance and empty states

## Question

After the Hall scaffold is placed, how does the game teach itself? Decide: the short list of hints (go exercise, what the bars mean, what workers do, what the "!" is, what food shortage means), when each shows and how it is dismissed, what empty states say (no data yet, no workers, nothing to build), and what is cut from the MVP.

Keep it small. This is the tutorial and it is not a separate mode.

## Resolution

Decided with Steven. Round 1 hints were accepted as a start, to be tightened later. Prototype: `prototypes/17-hints.html`.

- **Delivery:** hints show in the dialog box (ticket 13) as a box with text and a pulsing outline on the thing it points at. No tutorial mode. A hint is a plain event.
- **Hints (data rows: trigger, text, target):** go exercise (Hall placed), what the rings mean (first scaffold), no workers (scaffold has 0), what the "!" is (first ready building), food short (food first hits 0).
- **Ending:** "Got it" closes a hint for good. A saved "seen" list. "Don't show tips" on every hint turns all tips off.
- **Settings (new):** a Settings sheet from a gear button. It has a "Show tips" switch and "Show all tips again". Settings was not in the MVP list before. Only this one section is added.
- **Empty states:** no workers (worker badge on the building), no free people ("Build a house for more people" in the people popover), nothing to build (locked carousel rows with the Hall level), no data yet (the daily note from ticket 16).
- **Cut from MVP:** characters, portraits, story, quests, replayable tutorials, a help screen. The dialog box stays.
- **Debug:** a reset of the seen list.

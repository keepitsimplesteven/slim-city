---
type: grilling
status: closed
blocked-by: []
claimed: steven
---

# Art plan: build stages and Kenney pieces

## Question

How does each building look at 25%, 50%, 75% and 100% (ticket 12), and where do the pieces come from? Use the inventory from ticket 19. Notes idea: a tile is a 2x2 grid of Kenney pieces, so buildings look more detailed without changing the grid scale.

Decide: one shared scaffold look vs per-building stages, how stages are built from pieces, which MVP buildings get real art first (house and Village Hall are likely), and which stay as placeholders. Check the rendering cost on a phone.

## Resolution

Decided with Steven (Q1 to Q6).

- **Stages:** one model per building, built from named parts (for example `stage1_poles`). Each stage (25, 50, 75, 100%) is a list of part names in data. 25% is a base with poles, 50% adds walls, 75% adds a partial roof, 100% is the finished building.
- **Shared scaffold:** the default for any building without its own stage parts. A fenced pad with poles and planks sized to the footprint, tinted as progress grows. Every building works on day one with it.
- **Art order:** Village Hall and House get real art first. All others use a plain box in their color plus the shared scaffold. Farm, Lumber mill and Quarry are next.
- **Pipeline:** Kenney pieces joined by repo scripts into one USDZ per building (`scripts/build_house.py`, `scripts/obj_to_usdz.swift`). The GLB route is untested and not relied on. Each stage is merged into one mesh so a building costs a few draw calls, not one per piece.
- **Detail:** "pieces per tile side" is a data number on each building. It starts at 2 (a 3x3 Hall is a 6x6 grid of pieces). Steven wants more detail than 2 later, so it can rise to 3 or 4 once a layout script exists and a device shows the frame rate.
- **Phone cost:** a spec task measures frame rate with 30 buildings with staged parts. A parts-per-building limit sits in data, starting near 40 (to be revisited with the detail number).

## Numbers behind the detail choice

Kenney pieces have about 300 faces each (median 336, walls about 200, windows about 380), and they keep all faces when scaled. Hall (3x3 tiles): 1 per side is about 3,000 faces, 2 is about 11,000, 3 is about 24,000, 4 is about 43,000. Drawing is fine if stages are merged. Making grows with the square of the detail, so a layout script that builds a building from data is needed above 2.

## Not decided

- A script that builds a building from a layout (walls, windows, roof) in data.
- The parts limit at higher detail. It must be re-set with the detail number.
- Real device frame rate. Untested.

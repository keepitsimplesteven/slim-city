---
type: research
status: closed
blocked-by: []
claimed: steven
---

# Kenney asset inventory

## Question

What do the Kenney packs in `Assets/` offer for our buildings? List, for each pack, the pieces (walls, roofs, scaffolding, fences, props), their format (OBJ, GLB, USDZ), their size in units, and the license terms. Match them to the MVP building list: Village Hall, House, Farm, Lumber mill, Quarry, Bank, Carpenter's Workshop, Mission board, Marketplace, Records. Note what is missing, and what could serve as a scaffold or construction stage.

## Resolution

Full findings: [research/19-kenney-inventory.md](../research/19-kenney-inventory.md).

**Packs.** Four packs have 3D models: Fantasy Town 2.0, Castle Kit, Mini Forest, Tower Defense Kit. All are CC0, and credit is optional. The other packs are 2D art or sound. Each ships FBX, GLB and OBJ+MTL. None ships USDZ. The Fantasy Town models live in `Assets/Models/`, not in its own folder, which holds only previews. Pieces are about one tile square (Fantasy Town walls 0.1 x 1.0 x 1.0, Castle Kit walls 1.31 tall).

**App loading.** `BuildingEntityFactory` loads only `<modelName>.usdz` from the app bundle and falls back to a box. It does no scaling and has no stage support. The repo already has a route: `scripts/build_house.py` joins OBJ pieces, then `scripts/obj_to_usdz.swift` makes a USDZ. GLB has no tested route. `ARCHITECTURE_SEAMS.md` is out of date (it still says SceneKit).

**Fit to the MVP buildings.**

| Building | Fit | Missing |
|---|---|---|
| House | Already built | Nothing |
| Marketplace | Best fit (stalls, cart, fountain) | Crates and goods |
| Village Hall | Walls, roof, stairs, towers | One large hall model |
| Farm | Fences, hedges, cart, windmill | Crops, hay, animals, barn |
| Lumber mill | Watermill, wheel, planks, logs | A saw, a log stack |
| Quarry | Rocks, cart, stairs | A pit, tools, ore |
| Bank | Stone walls, pillars, gate | Coins, vault, sign |
| Carpenter's Workshop | Wood walls, planks, poles, stall | Workbench, tools |
| Mission board | Poles, planks, banners | A board or sign |
| Records | Stone walls, windows, roof | Books, shelves |

**Construction stages.**
- Tower Defense has six ready build stages, for towers only.
- Mini Forest has a three-step hut (platform, structure, roof) and a ladder.
- Fantasy Town poles, planks and wood pillars match the wall scale. Partial builds (walls without a roof) can be middle stages.
- Stages need either one USDZ per stage or code that shows and hides parts of one model.

**Passed to ticket 18:** all of the above. Not tested: the GLB route, and anything on a real device.

# Research 19: Kenney asset inventory

Ticket: `/Users/stevenalbers/projects/kiro-workspace/slim-city/docs/wayfinder/tickets/19-kenney-inventory.md`
Method: file listing of `/Users/stevenalbers/projects/kiro-workspace/slim-city/Assets`, vertex bounds read from the OBJ files (min/max of `v` lines), `License.txt` in each pack, and a read of the render code and `scripts/`. Nothing was edited. Sizes are in model units, where 1.0 is one Kenney tile (see Conventions).

## Summary

- Four packs hold 3D models: Fantasy Town Kit 2.0, Castle Kit 2.0, Mini Forest 1.0 and Tower Defense Kit 2.1. The other four (board-game-icons, cartography-pack, interface-sounds, ui-pack-adventure) are 2D art or audio and have no building pieces.
- Every pack is CC0. No attribution is required. Crediting "Kenney" is optional.
- Every model pack ships FBX, GLB and OBJ(+MTL). **No pack ships USDZ or USDA.**
- The app loads `<modelName>.usdz` from the bundle. OBJ converts to USDZ with the repo's own `scripts/obj_to_usdz.swift`, which already produced `house.usdz`.
- Fantasy Town Kit covers most of the 10 buildings. Missing: a bank/vault look, a mine entrance, a mission/notice board, a records/archive look, a crop field, a sawmill saw and a stockpile of cut logs. Several of these can be assembled from existing pieces plus small props.
- Scaffold/construction stage: Tower Defense Kit `wood-structure*` and `tower-*-build-*`, Fantasy Town Kit `poles`, `planks` and `pillar-wood`, and Mini Forest `building-structure`, `building-platform` and `ladder`.

## Conventions

- All packs use a 1 x 1 tile footprint with the origin at the bottom of the model. Models point +Y up.
- A wall piece is a thin slab on the +x edge. Fantasy Town wall: 0.10 x 1.0 x 1.0 (x, y, z). Castle Kit wall: 1.0 x 1.31 x 1.0.
- The repo's `scripts/build_house.py` treats one grid tile as a 2 x 2 block of half-scale Kenney cells (scale 0.5), so walls become 0.5 tall and the house is 2 floors in one tile. This is the existing way of fitting Kenney scale to the game's tile size. Whether one game tile equals one Kenney tile is a decision for the sizing ticket. Footprint of each building is not defined in this ticket.
- Textures: each pack uses one shared palette image (`Textures/colormap.png`), plus `variation-a.png` (Fantasy Town) or `variation-a..g.png` (Castle Kit) in the pack's `Models/Textures` folder for colour variants. Materials are a single `colormap` material per OBJ.

## Pack 1: Fantasy Town Kit 2.0 (best fit)

Location: models live in `/Users/stevenalbers/projects/kiro-workspace/slim-city/Assets/Models/` (not inside `kenney_fantasy-town-kit_2`, which holds only previews, the overview page and 170 preview PNGs). Its `License.txt` is `/Users/stevenalbers/projects/kiro-workspace/slim-city/Assets/License.txt`.

- Formats: `FBX format/` (167 .fbx), `GLB format/` (167 .glb), `OBJ format/` (167 .obj + 167 .mtl), `Textures/` (`variation-a.png`).
- License: CC0 1.0. Commercial use allowed. Attribution optional.

Pieces relevant to buildings (names are file stems; most come in a plain/stone and a `-wood` variant):

| Group | Pieces | Size (x, y, z) |
|---|---|---|
| Walls | `wall`, `wall-wood`, `wall-half`, `wall-block`, `wall-corner`, `wall-corner-edge`, `wall-diagonal`, `wall-curved`, `wall-rounded`, `wall-broken`, `wall-slope`, `wall-side`, `wall-detail-*` | slab 0.10 x 1.0 x 1.0; `wall-half` 0.10 x 0.5 x 1.0; `wall-block` 1.0 x 1.0 x 1.0 |
| Doors/openings | `wall-door`, `wall-doorway-square`, `-round`, `-square-wide`, `-base`, `wall-arch`, `wall-arch-top` | 0.10 x 1.0 x 1.0 (`wall-arch` 0.1 x 1.0 x 0.3) |
| Windows | `wall-window-small`, `-glass`, `-round`, `-shutters`, `-stone` | 0.10 x 1.0 x 1.0 |
| Roofs | `roof`, `roof-gable`, `roof-point`, `roof-flat`, `roof-corner*`, `roof-left/right`, `roof-window`, `roof-high-*` (taller, 13 variants) | `roof` 1.07 x 0.65 x 1.0; `roof-gable` 1.1 x 0.57 x 1.08; `roof-high-gable` 1.1 x 1.15 x 1.14; `roof-point` 1.1 x 0.5 x 1.1 |
| Chimney, overhang, balcony | `chimney` (+`-base`, `-top`), `overhang`, `balcony-wall`, `balcony-wall-fence` | chimney 0.21 x 1.0 x 0.34 |
| Fences/hedges | `fence`, `fence-gate`, `fence-curved`, `fence-broken`, `hedge`, `hedge-gate`, `hedge-large*` | fence 0.08 x 0.38 x 1.0; hedge 0.25 x 0.25 x 1.0 |
| Scaffold-like | `poles` (1.0 high), `poles-horizontal`, `planks` (flat 1.0 x 0.06 x 1.0), `planks-half`, `planks-opening`, `pillar-wood`, `pillar-stone` | poles 0.10 x 1.0 x 1.0; pillar 0.16 x 1.0 x 0.16 |
| Stairs | `stairs-wood`, `stairs-stone`, `stairs-full*`, `stairs-wide-*` (with/without handrail) | `stairs-wood` 1.02 x 1.0 x 0.5 |
| Market | `stall`, `stall-red`, `stall-green`, `stall-bench`, `stall-stool` | `stall` 0.66 x 0.37 x 1.0 (counter only); `stall-red` 1.0 x 1.24 x 1.0 (awning) |
| Props | `cart`, `cart-high`, `lantern`, `banner-red`, `banner-green`, `blade`, `wheel`, `rock-large/small/wide`, `tree*`, `fountain-*` (11), `road*` (12) | cart 0.9 x 0.54 x 1.34; lantern 0.22 x 1.56 x 0.22; `tree` 1.02 x 2.41 x 1.02; `rock-large` 1.67 x 1.16 x 1.54; `fountain-round` 2.0 x 0.28 x 2.0 |
| Mills | `watermill`, `watermill-wide`, `windmill` | `watermill` 0.84 x 1.8 x 1.8 (origin at the wheel centre, y from -0.9 to 0.9); `windmill` 0.48 x 3.12 x 3.12 (y -1.56 to 1.56) |

Not present: farm crops/fields, animals, barrels, crates, sacks, logs, saws, ore/mine items, signs/notice boards, books, coins, anvils, doors as separate props.

## Pack 2: Castle Kit 2.0

Location: `/Users/stevenalbers/projects/kiro-workspace/slim-city/Assets/kenney_castle-kit/Models/`.

- Formats: FBX, GLB, OBJ+MTL, 76 models each; textures `variation-a..g.png`.
- License: CC0 1.0 (`/Users/stevenalbers/projects/kiro-workspace/slim-city/Assets/kenney_castle-kit/License.txt`).
- Style: stone castle. Walls are 1.31 tall, so about 31% taller than Fantasy Town pieces.

Relevant pieces:

| Group | Pieces | Size |
|---|---|---|
| Walls | `wall`, `wall-half`, `wall-narrow` (0.5 wide), `wall-narrow-wood`, `wall-narrow-wood-fence`, `wall-corner*`, `wall-pillar`, `wall-stud`, `wall-doorway`, `wall-narrow-gate`, `wall-to-narrow` | `wall` 1.0 x 1.31 x 1.0; `wall-narrow` 0.5 x 1.31 x 1.0 |
| Doors/gates | `door` (0.14 x 0.61 x 0.36), `gate` (0.16 x 0.91 x 0.66), `metal-gate` (0.08 x 0.73 x 0.7) | |
| Towers | `tower-square` (1.0 x 1.31 x 1.0), `tower-square-base/mid/top/roof` (roof 1.0 x 2.01 x 1.0), `tower-square-mid-door/windows/open`, `tower-hexagon-*`, `tower-slant-roof` (1.18 x 2.14 x 1.14) | |
| Stairs | `stairs-stone`, `stairs-stone-square`, `wall-narrow-stairs` | `stairs-stone` 0.24 x 0.68 x 0.82 |
| Banners | `flag`, `flag-banner-long/short`, `flag-pennant`, `flag-wide` | `flag` 0.1 x 0.87 x 0.43 |
| Props | `tree-log` (0.25 x 0.28 x 1.0), `tree-trunk`, `tree-large/small`, `rocks-large/small` (1.04 x 0.5 x 1.1), `bridge-*`, `ground`, `ground-hills` | |
| Siege | `siege-ram`, `-ballista`, `-catapult`, `-trebuchet`, `-tower` (+ `-demolished` variants) | `siege-tower` 1.96 x 2.68 x 1.2 |

Use for the MVP: `tower-square-*` and `wall*` can build a Village Hall or Bank with a fortified look. `tree-log` and `tree-trunk` are the only log props in any pack. The `-demolished` siege items are a ruined/wreck look, not a scaffold.

## Pack 3: Mini Forest 1.0

Location: `/Users/stevenalbers/projects/kiro-workspace/slim-city/Assets/kenney_mini-forest_1/Models/`.

- Formats: FBX, GLB, OBJ+MTL, 22 models each.
- License: CC0 1.0 (`/Users/stevenalbers/projects/kiro-workspace/slim-city/Assets/kenney_mini-forest_1/License.txt`).
- Full model list: `bridge`, `building-platform`, `building-roof`, `building-structure`, `character-archer`, `fence`, `flag`, `ladder`, `patch-dirt`, `patch-grass`, `plant`, `platform`, `rocks-high`, `rocks-low`, `rocks-ramp`, `stones`, `target`, `tent`, `tree`, `tree-high`, `weapon-arrow`, `weapon-bow`.

Sizes: `building-platform` 1.3 x 0.5 x 1.3; `building-structure` 1.0 x 1.0 x 1.0; `building-roof` 1.34 x 1.05 x 1.16; `platform` 1.0 x 0.47 x 1.0; `ladder` 0.5 x 1.0 x 0.14; `fence` 1.1 x 0.4 x 0.24; `tent` 1.26 x 1.0 x 1.08; `stones` 0.9 x 0.45 x 0.85; `plant` 0.4 x 0.19 x 0.44; `tree` 0.92 x 1.68 x 0.88; `patch-dirt` 1.0 x 0.1 x 1.0; `rocks-low` 1.0 x 0.52 x 1.0; `flag` 0.43 x 0.75 x 0.16.

Relevance: `building-platform` + `building-structure` + `building-roof` are a small stilted hut in three stacked stages, which doubles as a construction-stage sequence. `patch-dirt` (1.0 x 0.1 x 1.0) is a ready-made farm-plot tile. `rocks-low`, `rocks-high` and `stones` suit a quarry. `plant` and `patch-grass` are decoration only. The characters/weapons are not relevant.

## Pack 4: Tower Defense Kit 2.1

Location: `/Users/stevenalbers/projects/kiro-workspace/slim-city/Assets/kenney_tower-defense-kit/Models/`.

- Formats: FBX, GLB, OBJ+MTL, 160 models each.
- License: CC0 1.0 (`/Users/stevenalbers/projects/kiro-workspace/slim-city/Assets/kenney_tower-defense-kit/License.txt`).
- Mostly terrain tiles (`tile-*`, `snow-tile-*`, 1.0 x 0.2 x 1.0 for plain `tile`), enemy UFOs, weapons and modular towers. Little is a building.

Relevant pieces:

| Group | Pieces | Size |
|---|---|---|
| Wood scaffold | `wood-structure` (1.0 x 0.5 x 1.0), `wood-structure-high` (1.0 x 1.0 x 1.0), `wood-structure-part` (1.0 x 0.5 x 0.13), `wood-structure-high-part` (1.0 x 1.0 x 0.13), and `snow-` versions | |
| Tower build stages | `tower-square-build-a..f` and `tower-round-build-a..f`: six progressive construction stages, from 1.1 x 1.0 x 1.1 (a) to 1.0 x 1.72 x 1.0 (f) | |
| Tower modules | `tower-square-bottom/middle/top/roof-a..c` (bottom 1.0 x 0.5 x 1.0, roof-a 1.1 x 1.27 x 1.1), round equivalents | |
| Terrain/props | `tile`, `tile-rock` (1.0 x 0.61 x 1.0), `tile-crystal` (1.0 x 0.75 x 1.0), `tile-tree*`, `detail-rocks` (0.6 x 0.18 x 0.6), `detail-dirt`, `detail-tree` (0.34 x 0.53 x 0.34), `detail-crystal`, `weapon-catapult` | |

Relevance: the `wood-structure*` set is the closest thing to scaffolding in any pack. The `tower-*-build-*` series shows a tower going up in steps, which is the only ready-made multi-stage construction sequence. `tile-rock` and `detail-rocks` help a quarry. The `-crystal` items could serve as ore for a mine, but they have a sci-fi look.

## Other packs (checked for relevance only)

- `kenney_board-game-icons` (CC0): PNG/vector icons and a tilesheet. No 3D. Could provide UI icons for building types.
- `kenney_cartography-pack` (CC0): PNG/spritesheets/textures for maps. No 3D. Could style a minimap.
- `kenney_ui-pack-adventure` (CC0): UI sprites and vectors. No 3D.
- `kenney_interface-sounds` (CC0): audio only.

## Rendering in the existing app: USDZ, not USDA, not OBJ/GLB

Read from `/Users/stevenalbers/projects/kiro-workspace/slim-city/SlimCity/SlimCity/Render/BuildingEntityFactory.swift`:

- `BuildingEntityFactory` is a RealityKit `@MainActor` class. It looks up `bundle.url(forResource: modelName, withExtension: "usdz")` (bundle defaults to `.main`).
- `preload(modelNames:)` calls `try? await Entity(contentsOf: url)` for each name and stores a template. A load failure is silent, and that building falls back to a primitive box.
- `entity(forModelName:)` returns a container holding `template.clone(recursive: true)`, named `building:<modelName>`. No model is found, so it returns a coloured box (0.8 x 0.6 x 0.8, 0.6 high).
- Only the `.usdz` extension is searched. A `.usda`, `.usdc`, `.obj` or `.glb` in the bundle will not be found. (There was a `house.usda` build output in `SlimCity/.build-sim/...`. It is a build artefact, not a loaded asset.)
- The factory applies no scaling or offset. Models must be authored so the origin is at the base centre and the size fits one tile.
- The bundled model is `/Users/stevenalbers/projects/kiro-workspace/slim-city/SlimCity/SlimCity/Models/house.usdz` (148 KB: `house.usdc` + `0/colormap.png`). Git history: it was first a Kenney house, then replaced by "detailed two-storey house built from half-size kenney pieces".
- Documentation drift: `/Users/stevenalbers/projects/kiro-workspace/slim-city/SlimCity/ARCHITECTURE_SEAMS.md` still describes a SceneKit `BuildingNodeFactory` / `SCNScene(url:)` and a `house.usda`. The code now uses RealityKit `BuildingEntityFactory`. The seam idea is unchanged.
- I did not confirm the `modelName` values in the catalog (the core search found no `modelName:` literals outside tests). The docs say `house`, `farm`, `market`. TODO.md lists `farm.usdz` and `market.usdz` as the next art drops.

### Conversion step from OBJ/GLB

The repo already has the pipeline:

1. `python3 scripts/build_house.py [OUT_DIR]` reads `Assets/Models/OBJ format/*.obj` (or `$KENNEY_PACK`), places pieces with a position, a Y turn and a scale, and writes one combined `house.obj` + MTL + textures. It is hard-coded to Fantasy Town pieces and a house layout, so each new building needs a new layout script or a generalised one.
2. `swiftc scripts/obj_to_usdz.swift -o obj_to_usdz && ./obj_to_usdz house.obj house.usdz` loads the OBJ with SceneKit `SCNScene(url:)` and writes USDZ with `scene.write(to:)`. The OBJ's MTL must sit beside the textures folder.
3. Copy the result to `SlimCity/SlimCity/Models/<modelName>.usdz`. Assets are validated with `usdchecker` per the seams note.

Notes and risks:

- Use OBJ as the source. SceneKit reads OBJ+MTL directly. GLB is not read by SceneKit on this path, so GLB would need a different tool (Reality Converter, Blender, or `usd_from_gltf`). None of `usdconvert`, `usd_from_gltf`, Blender, assimp, trimesh or `pxr` is installed on this machine, so the OBJ + Swift script is the only tested route here. I did not run a conversion.
- OBJ has no animation. `watermill`/`windmill` rotating parts (`wheel`, `blade`) would need a manual rig or code to spin, and their origins are at the wheel centre, not the base.
- Each combined building is one mesh set with one 256-ish px colormap, so draw cost is small. Different tints per building need either a variation texture or a separate material.
- Construction stages mean extra USDZ files per building (e.g. `<name>_scaffold.usdz`), or one file and code to show/hide child entities. The factory has no stage support today, so this is a design decision for another ticket.

## Match to the MVP buildings

Legend: **Have** = exists in a pack; **Compose** = built from several pieces; **Missing** = no suitable piece.

| Building | Pieces that could make it | Missing |
|---|---|---|
| Village Hall | Compose from Fantasy Town `wall*`, `wall-door`/`wall-doorway-*`, `wall-window-*`, `roof-high-gable`, `chimney`, `stairs-stone`, `banner-*`, `pillar-stone`, `lantern`; or Castle Kit `tower-square-*` + `flag*` for a grander look | No single large hall model. A hall bigger than one tile needs a footprint decision |
| House | Have: already built (`scripts/build_house.py`; `wall`, `wall-door`, `wall-window-*`, `roof-gable`, `chimney`) | Nothing |
| Farm | Fantasy Town `fence*`, `hedge*`, `cart`, `wall-*`/`roof-*` for a barn, `windmill`; Mini Forest `patch-dirt` for plots, `fence`, `plant` | Crops, haystacks, animals, barn, tools. Barn must be composed |
| Lumber mill | Fantasy Town `watermill`, `wheel`, `wall-wood*`, `roof*`, `planks*`, `poles`, `cart`; Castle Kit `tree-log`, `tree-trunk`; Fantasy Town `tree` | Saw, log stack, sawn timber. Only one log prop (`tree-log`); a pile means repeating it |
| Quarry | Fantasy Town `rock-large/small/wide`, `cart`, `stairs-stone`; Mini Forest `rocks-low/high/ramp`, `stones`; Castle Kit `rocks-*`; Tower Defense `tile-rock`, `detail-rocks` | Pickaxe, ore, cut blocks, crane. A pit or terrain cut would need a custom shape. `wall-block` (1.0 cube) could stand in for cut stone |
| Bank | Compose from Fantasy Town stone `wall*`, `wall-doorway-square`, `pillar-stone`, `roof`, `stairs-stone`; Castle Kit `metal-gate`, `gate`, `wall-narrow-gate` for a vault door, `tower-square-*` | Coins, vault, safe, sign. Nothing says "bank" without a sign or colour cue |
| Carpenter's Workshop | Fantasy Town `wall-wood*`, `wall-wood-window-*`, `roof*`, `planks*`, `poles`, `cart`, `stall`; Tower Defense `wood-structure*` | Workbench, tools, saw, timber stacks. `stall` and `planks` can act as a bench |
| Mission board | Fantasy Town `wall-wood-half`, `poles`, `planks`, `banner-red/green`, `lantern`, `pillar-wood` | No board or sign model. Compose a post + planks board with banners. Needs a small custom piece or a texture decal |
| Marketplace | Fantasy Town `stall`, `stall-red`, `stall-green`, `stall-bench`, `stall-stool`, `cart`, `lantern`, `banner-*`, `fountain-*`, `road*` | Goods (crates, sacks, fruit). The stalls are the closest to a finished product in any pack |
| Records | Compose from Fantasy Town stone `wall*`, `wall-window-*`, `roof*`, `stairs-stone`, `pillar-stone`; Castle Kit `tower-square-*` | Books, shelves, scrolls, desks. No archive-specific piece; a tower plus a banner colour would give it identity |

### Scaffold / construction-stage candidates

1. Tower Defense `tower-square-build-a..f` and `tower-round-build-a..f`: six ready-made stages for a tower-shaped building (square/round). Most direct fit for a staged build.
2. Tower Defense `wood-structure` (0.5 high) and `wood-structure-high` (1.0 high), plus `-part` panels (thin 0.13 wall frames). These stack as a wooden frame.
3. Mini Forest `building-platform` (0.5) then `building-structure` (1.0) then `building-roof` (1.05): three stages of one hut. Also `ladder`.
4. Fantasy Town `poles` and `poles-horizontal` (1.0 x 1.0 wall-slab frames), `planks`, `planks-half`, `planks-opening`, `pillar-wood`: lets you build a per-building scaffold at the same scale as the finished walls, or build the building only part-way up (floor 0 walls without the roof) as an intermediate stage.
5. A cheap staging approach for any building: stage 1 `planks` base, stage 2 `poles` + `pillar-wood`, stage 3 walls without the roof, stage 4 full model. All use Fantasy Town pieces, so the scale matches.

Scale caution: the Tower Defense and Mini Forest pieces use 1.0-tile footprints with different heights (Castle Kit walls 1.31, Fantasy Town walls 1.0). Mixing packs in one building needs per-piece scaling or accepting small height mismatches. Fantasy Town wall slabs are 0.10 thick. Castle Kit walls are a full 1.0 deep, so they do not mix cleanly.

## Open questions for later tickets

- Tile-to-model scale: one game tile vs one Kenney tile, and the footprint of large buildings (hall, bank, lumber mill).
- Construction stages: separate USDZ per stage, or hide/show child entities in code (the factory has neither today).
- Whether the `modelName` list in the catalog matches the 10 buildings. I did not find the catalog values.
- Whether to generalise `scripts/build_house.py` into a layout-driven script for all 10 buildings.

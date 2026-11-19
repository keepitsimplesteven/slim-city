#!/usr/bin/env python3
"""Builds a Slim City house from Kenney Fantasy Town Kit pieces.

Each 1x1 grid tile is treated as a 2x2 block of half-size Kenney cells, so the
house gets real detail (door, windows, a second floor) while still fitting
exactly one tile. No dependencies; writes a plain OBJ + MTL.

Usage:
    python3 scripts/build_house.py [OUT_DIR]
then:
    swiftc scripts/obj_to_usdz.swift -o OUT_DIR/obj_to_usdz
    (cd OUT_DIR && ./obj_to_usdz house.obj house.usdz)

Kenney pieces are 1x1 tiles with a wall on the +x edge (turn 0). Turning a
piece around Y moves that wall to another edge of the cell.
"""
import math
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Set KENNEY_PACK to the pack folder if it lives outside the repo (e.g. a
# staging directory); default is the git-ignored Assets/ folder.
PIECES = os.path.join(
    os.environ.get("KENNEY_PACK", os.path.join(ROOT, "Assets")), "Models", "OBJ format"
)

CELL = 0.5            # a cell is half a tile; also the piece scale
FLOORS = 2            # stories of walls; each is CELL tall
ROOF_SCALE = 0.9      # roof overhang stays inside the tile (native x is +-0.55)

# Cell column (x) / row (z): 0 or 1. Center = (index - 0.5) * CELL.
# Turn (degrees about Y) that puts a wall on each side of a cell.
SIDE_TURN = {"east": 0, "south": -90, "west": 180, "north": 90}
# Which side of the house a cell touches, by (col, row).
def outer_sides(col, row):
    sides = []
    if col == 1: sides.append("east")
    if col == 0: sides.append("west")
    if row == 1: sides.append("south")   # +z, faces the camera
    if row == 0: sides.append("north")
    return sides

def wall_piece(floor, col, row, side):
    """Pick the Kenney wall for one side of one cell on one floor."""
    if side == "south":                      # front
        if floor == 0:
            return "wall-door" if col == 0 else "wall-window-small"
        return "wall-window-shutters"
    if side == "east":                       # right
        return "wall-window-small" if (floor == 1 or row == 1) else "wall"
    return "wall-window-small" if floor == 1 else "wall"   # back / left


def build_placements():
    """(piece, turn_degrees, scale, x, y, z) for every part."""
    parts = []
    for floor in range(FLOORS):
        y = floor * CELL
        for col in (0, 1):
            for row in (0, 1):
                cx, cz = (col - 0.5) * CELL, (row - 0.5) * CELL
                for side in outer_sides(col, row):
                    parts.append((wall_piece(floor, col, row, side),
                                  SIDE_TURN[side], CELL, cx, y, cz))
    top = FLOORS * CELL
    parts.append(("roof-gable", 0, ROOF_SCALE, 0.0, top, 0.0))
    parts.append(("chimney", 0, CELL, 0.0, top - 0.05, -0.12))
    return parts


# ---------- OBJ reading / writing ----------

def load_obj(path):
    v, vt, vn, items = [], [], [], []
    for line in open(path):
        p = line.split()
        if not p:
            continue
        k = p[0]
        if k == "v":
            v.append(tuple(map(float, p[1:])))      # x y z [r g b]
        elif k == "vt":
            vt.append(tuple(map(float, p[1:3])))
        elif k == "vn":
            vn.append(tuple(map(float, p[1:4])))
        elif k == "usemtl":
            items.append(("mat", p[1]))
        elif k == "f":
            refs = []
            for t in p[1:]:
                a = [int(x) if x else 0 for x in t.split("/")]
                refs.append(tuple((a + [0, 0, 0])[:3]))
            items.append(("f", refs))
    return v, vt, vn, items


def read_materials(path):
    mats, cur = {}, None
    for line in open(path):
        if line.startswith("newmtl"):
            cur = line.split()[1]
            mats[cur] = []
        if cur:
            mats[cur].append(line.rstrip("\n"))
    return {k: "\n".join(v) for k, v in mats.items()}


def turn_y(x, y, z, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return (x * c + z * s, y, -x * s + z * c)


def assemble(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    cache, materials = {}, {}
    ov = ovt = ovn = 0
    lv, lvt, lvn, lf = [], [], [], []
    last_mat = None
    for n, (name, turn, scale, px, py, pz) in enumerate(build_placements()):
        if name not in cache:
            path = os.path.join(PIECES, name + ".obj")
            cache[name] = load_obj(path)
            materials.update(read_materials(os.path.join(PIECES, name + ".mtl")))
        v, vt, vn, items = cache[name]
        for p in v:
            x, y, z = turn_y(p[0] * scale, p[1] * scale, p[2] * scale, turn)
            extra = "".join(f" {q:g}" for q in p[3:])
            lv.append(f"v {x + px:.5f} {y + py:.5f} {z + pz:.5f}{extra}")
        lvt += [f"vt {u:g} {w:g}" for u, w in vt]
        for nx, ny, nz in vn:
            x, y, z = turn_y(nx, ny, nz, turn)
            lvn.append(f"vn {x:.5f} {y:.5f} {z:.5f}")
        lf.append(f"o {name}_{n}")
        for kind, data in items:
            if kind == "mat":
                if data != last_mat:
                    lf.append(f"usemtl {data}")
                    last_mat = data
                continue
            refs = []
            for vi, ti, ni in data:
                s = str(vi + ov)
                if ti or ni:
                    s += "/" + (str(ti + ovt) if ti else "")
                if ni:
                    s += "/" + str(ni + ovn)
                refs.append(s)
            lf.append("f " + " ".join(refs))
        ov, ovt, ovn = ov + len(v), ovt + len(vt), ovn + len(vn)

    with open(os.path.join(out_dir, "house.obj"), "w") as f:
        f.write("# built by scripts/build_house.py\nmtllib house.mtl\n")
        f.write("\n".join(lv + lvt + lvn + lf) + "\n")
    with open(os.path.join(out_dir, "house.mtl"), "w") as f:
        f.write("\n\n".join(materials.values()) + "\n")
    shutil.copytree(os.path.join(PIECES, "Textures"),
                    os.path.join(out_dir, "Textures"), dirs_exist_ok=True)

    xs = [float(l.split()[1]) for l in lv]
    ys = [float(l.split()[2]) for l in lv]
    zs = [float(l.split()[3]) for l in lv]
    print(f"{len(build_placements())} pieces, {len(lv)} verts")
    print(f"bounds x[{min(xs):.3f},{max(xs):.3f}] y[{min(ys):.3f},{max(ys):.3f}] "
          f"z[{min(zs):.3f},{max(zs):.3f}]  (tile is x,z in [-0.5,0.5])")


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, ".build-sim", "house")
    assemble(out)

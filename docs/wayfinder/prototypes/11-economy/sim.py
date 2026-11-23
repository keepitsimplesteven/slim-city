#!/usr/bin/env python3
"""Throwaway economy sim for wayfinder ticket 11. Reads data.json. Usage: python3 sim.py [data.json] [--daily player template]"""
import json, sys
from collections import Counter

def curve(cfg, n):
    c = cfg["worker_curve"]
    return c[min(n, len(c) - 1)]

def progress(cfg, raw):
    ov = cfg["overflow"]
    if ov["enabled"]:
        return min(raw, 1) + max(0, min(raw, ov["max_raw"]) - 1) * ov["rate"], raw > ov["max_raw"]
    return min(raw, cfg["cap"]), raw > cfg["cap"]

def run(cfg, raw, steps, verbose=False):
    R = list(cfg["sources"])
    wallet = dict(cfg["start"]["wallet"])
    people = cfg["start"]["people"]
    blds = []            # open buildings
    tasks = []           # scaffolds
    hall_lv = 0
    idx = 0
    st = Counter()       # blocked-day reasons
    mil = {}             # milestones: name -> day
    hungry = capdays = unused_cw = free_days = 0
    min_food = 10**9
    upgraded = set()
    log = []

    def cw_cap():
        n = cfg["hall"]["construction_workers"]
        n += sum(cfg["buildings"][b["type"]].get("construction_workers", 0) for b in blds)
        return n

    def afford(cost):
        return all(wallet[r] >= n for r, n in cost.items())

    def short(cost):
        return max(cost, key=lambda r: cost[r] - wallet[r])

    def place(kind, typ, cost, bars):
        for r, n in cost.items():
            wallet[r] -= n
        tasks.append({"kind": kind, "type": typ, "bars": {r: [0.0, n] for r, n in bars.items() if n > 0}, "w": 0, "ready": False})

    def have_open(t):
        return any(b["type"] == t for b in blds)

    for day in range(1, cfg["days"] + 1):
        # 1. ribbon cut: ready scaffolds open
        for t in [t for t in tasks if t["ready"]]:
            tasks.remove(t)
            if t["kind"] == "build":
                b = {"type": t["type"], "w": 0, "pw": cfg["buildings"].get(t["type"], {}).get("per_worker", 1.0), "up": 0}
                if t["type"] == "hall":
                    hall_lv = 1; mil["hall1"] = day
                    people += cfg["hall"]["people_per_level"]
                else:
                    blds.append(b)
                    people += cfg["buildings"][t["type"]].get("people", 0)
                    mil.setdefault("first_" + t["type"], day)
            elif t["kind"] == "hall":
                hall_lv += 1; mil["hall%d" % hall_lv] = day
                people += cfg["hall"]["people_per_level"]
            else:
                up = cfg["upgrades"][t["type"]]
                b = next(b for b in blds if b["type"] == t["type"])
                b["pw"] += up.get("per_worker_add", 0)
                people += up.get("people", 0)
                mil.setdefault("upgrade_" + t["type"], day)
        # 2. policy: take the next steps while affordable
        while idx < len(steps):
            s = steps[idx]; kind, _, typ = s.partition(":")
            if kind == "hall":
                if hall_lv >= cfg["hall"]["max_level"]:
                    idx += 1; continue
                if any(t["kind"] == "hall" for t in tasks):
                    st["hall-busy"] += 1; break
                if hall_lv < 1:
                    st["hall-not-open"] += 1; break
                need = cfg["hall"]["requires"].get(str(hall_lv), [])
                miss = [n for n in need if not have_open(n)]
                if miss:
                    st["prereq:" + ",".join(miss)] += 1; break
                place("hall", "hall", {}, cfg["hall"]["effort"][str(hall_lv + 1)]); idx += 1
            elif kind == "build":
                d = cfg["buildings"][typ]
                if typ != "hall" and hall_lv < max(d["lv"], 1):
                    st["locked"] += 1; break
                if not afford(d["cost"]):
                    st["short:" + short(d["cost"])] += 1; break
                place("build", typ, d["cost"], d["cost"]); idx += 1
            else:
                key = typ
                if not have_open(typ) or key in upgraded or any(t["kind"] == "upgrade" and t["type"] == typ for t in tasks):
                    st["upgrade-n/a"] += 1; break
                up = cfg["upgrades"][typ]
                if not afford(up["cost"]):
                    st["short:" + short(up["cost"])] += 1; break
                upgraded.add(key); place("upgrade", typ, up["cost"], up["cost"]); idx += 1
        if idx >= len(steps):
            st["template-done"] += 1
        # 3. workers: construction first (oldest scaffold first), rest to production
        pool = people
        cw = min(cw_cap(), pool)
        left = cw
        for t in tasks:
            t["w"] = min(left, cfg["max_workers_per_scaffold"]); left -= t["w"]
        unused_cw += left if tasks else cw
        pool -= cw
        for b in blds:
            cap = cfg["buildings"][b["type"]]["capacity"]
            b["w"] = min(cap, pool); pool -= b["w"]
        free = pool; free_days += free
        # 4. earn
        p, bite = progress(cfg, raw)
        capdays += bite
        for r in R:
            base = cfg["sources"][r]["base"]
            add = mult = 0; mult = 1.0
            for b in blds:
                d = cfg["buildings"][b["type"]]
                if d.get("produces") == r:
                    add += d["add"]; mult *= b["pw"] ** b["w"]
            wallet[r] += (base + add) * p * mult
            fill = base * p * cfg["assemble"]
            for t in tasks:
                if r in t["bars"]:
                    bar = t["bars"][r]; bar[0] = min(bar[1], bar[0] + fill * curve(cfg, t["w"]))
        for t in tasks:
            if all(v[0] >= v[1] for v in t["bars"].values()):
                t["ready"] = True
        # 5. eat
        wallet["food"] -= people * cfg["food_per_person_day"]
        if wallet["food"] < 0:
            wallet["food"] = 0; hungry += 1
        min_food = min(min_food, wallet["food"])
        if verbose:
            print("day %2d people %2d free %d tasks %d  %s" % (day, people, free, len(tasks), " ".join("%s=%d" % (r, wallet[r]) for r in R)))
    return {"mil": mil, "wallet": wallet, "people": people, "hungry": hungry, "capdays": capdays,
            "blocked": st, "unused_cw": unused_cw, "free_days": free_days, "hall": hall_lv, "steps_done": idx, "steps": len(steps)}

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    cfg = json.load(open(args[0] if args else "data.json"))
    if "--daily" in sys.argv:
        pl, tp = sys.argv[sys.argv.index("--daily") + 1:][:2]
        run(cfg, cfg["players"][pl], cfg["templates"][tp], True); return
    print("days: %d  cap: %s  overflow: %s\n" % (cfg["days"], cfg["cap"], cfg["overflow"]["enabled"]))
    hdr = "%-8s %-8s %-4s %-6s %-6s %-5s %-6s %-6s %-5s %-7s %s"
    print(hdr % ("player", "plan", "hall", "1stHse", "hall2", "ppl", "hungry", "capDay", "idleW", "steps", "end wallet f/w/s/g | top block reasons"))
    for pl, raw in cfg["players"].items():
        for tp, steps in cfg["templates"].items():
            r = run(cfg, raw, steps); m = r["mil"]; w = r["wallet"]
            top = ", ".join("%s:%d" % kv for kv in r["blocked"].most_common(3))
            print(hdr % (pl, tp, r["hall"], m.get("first_house", "-"), m.get("hall2", "-"), r["people"], r["hungry"], r["capdays"], r["unused_cw"], "%d/%d" % (r["steps_done"], r["steps"]),
                         "%d/%d/%d/%d | %s" % (w["food"], w["wood"], w["stone"], w["gold"], top)))

main()

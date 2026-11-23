#!/usr/bin/env python3
"""Throwaway economy sim for wayfinder ticket 11. Reads data.json.
  python3 sim.py                          table over many seeds
  python3 sim.py --log PLAYER PLAN [DAYS] detailed day-by-day log, seed 1
"""
import json, random, sys
from collections import Counter

RING = {"food": "move", "wood": "exercise", "stone": "stand", "gold": "steps"}

def curve(cfg, n):
    c = cfg["worker_curve"]; return c[min(n, len(c) - 1)]

def progress(cfg, raw):
    ov = cfg["overflow"]
    if ov["enabled"]:
        return min(raw, 1) + max(0, min(raw, ov["max_raw"]) - 1) * ov["rate"], raw > ov["max_raw"]
    return min(raw, cfg["cap"]), raw > cfg["cap"]

def run(cfg, persona, steps, seed, log=None):
    rnd = random.Random(seed)
    R = list(cfg["sources"])
    wallet = dict(cfg["start"]["wallet"]); people = cfg["start"]["people"]
    blds, tasks, done = [], [], set()
    hall_lv = 0
    st = Counter(); mil = {}
    hungry = rescue_days = capdays = idle_cw = 0
    resc = cfg["food_rescue"]
    fpd = cfg["food_per_person_day"]
    def say(*a):
        if log is not None: log.append(" ".join(str(x) for x in a))
    def cw_cap():
        return cfg["hall"]["construction_workers"] + sum(cfg["buildings"][b["type"]].get("construction_workers", 0) for b in blds)
    def afford(c): return all(wallet[r] >= n for r, n in c.items())
    def short(c): return max(c, key=lambda r: c[r] - wallet[r])
    def have_open(t): return any(b["type"] == t for b in blds)
    def count(t): return sum(b["type"] == t for b in blds) + sum(t2["kind"] == "build" and t2["type"] == t for t2 in tasks)
    def place(kind, typ, cost, bars, label):
        for r, n in cost.items(): wallet[r] -= n
        tasks.append({"kind": kind, "type": typ, "label": label, "bars": {r: [0.0, n] for r, n in bars.items() if n > 0}, "w": 0, "ready": False})
        say("   + start", label, "pay", fmt(cost) or "nothing", "| bars", fmt(bars))
    def fmt(d): return " ".join("%s%s" % (r[0], round(n, 1)) for r, n in d.items())
    prev_hungry = False
    for day in range(1, cfg["days"] + 1):
        say("== day %d" % day)
        # 1. ribbon cut
        for t in [t for t in tasks if t["ready"]]:
            tasks.remove(t)
            if t["kind"] == "build":
                if t["type"] == "hall":
                    hall_lv = 1; people += cfg["hall"]["people_per_level"]; mil["hall1"] = day
                else:
                    blds.append({"type": t["type"], "w": 0, "pw": cfg["buildings"][t["type"]].get("per_worker", 1.0)})
                    people += cfg["buildings"][t["type"]].get("people", 0)
                    mil.setdefault("first_" + t["type"], day)
            elif t["kind"] == "hall":
                hall_lv += 1; people += cfg["hall"]["people_per_level"]; mil["hall%d" % hall_lv] = day
            else:
                up = cfg["upgrades"][t["type"]]
                next(b for b in blds if b["type"] == t["type"])["pw"] += up.get("per_worker_add", 0)
                people += up.get("people", 0)
            say("   * opened", t["label"], "| people now", people)
        # 2. food rescue check
        rescue = resc["enabled"] and hall_lv >= 1 and (wallet["food"] < resc["trigger_days"] * people * fpd or prev_hungry)
        if rescue:
            rescue_days += 1; say("   ! food rescue: farms first, no new builds except farms")
            if count("farm") < resc["max_auto_farms"] and afford(cfg["buildings"]["farm"]["cost"]):
                c = cfg["buildings"]["farm"]["cost"]; place("build", "farm", c, c, "build farm (rescue)")
        # 3. policy
        if not rescue:
            for i, s in enumerate(steps):
                if i in done: continue
                kind, _, typ = s.partition(":")
                if kind == "hall":
                    if hall_lv >= cfg["hall"]["max_level"]: done.add(i); continue
                    if any(t["kind"] == "hall" for t in tasks): st["hall-busy"] += 1; continue
                    if hall_lv < 1: st["hall-not-open"] += 1; continue
                    miss = [n for n in cfg["hall"]["requires"].get(str(hall_lv), []) if not have_open(n)]
                    if miss: st["prereq:" + ",".join(miss)] += 1; continue
                    e = cfg["hall"]["effort"][str(hall_lv + 1)]
                    place("hall", "hall", {}, e, "hall -> level %d" % (hall_lv + 1)); done.add(i)
                elif len(tasks) >= cw_cap() and cfg["limit_scaffolds_to_workers"]:
                    st["no-builder"] += 1; continue
                elif kind == "build":
                    d = cfg["buildings"][typ]
                    if typ != "hall" and hall_lv < max(d["lv"], 1): st["locked"] += 1; continue
                    if not afford(d["cost"]):
                        st["short:" + short(d["cost"])] += 1; break
                    place("build", typ, d["cost"], d["cost"], "build " + typ); done.add(i)
                else:
                    busy = any(t["kind"] == "upgrade" and t["type"] == typ for t in tasks)
                    if not have_open(typ) or busy: st["upgrade-n/a"] += 1; continue
                    up = cfg["upgrades"][typ]
                    if not afford(up["cost"]): st["short:" + short(up["cost"])] += 1; break
                    place("upgrade", typ, up["cost"], up["cost"], "upgrade " + typ); done.add(i)
        # 4. workers
        pool = people
        farms = [b for b in blds if b["type"] == "farm"]
        for b in blds: b["w"] = 0
        if rescue:
            for b in farms:
                n = min(cfg["buildings"]["farm"]["capacity"], pool); b["w"] = n; pool -= n
        cw = min(cw_cap(), pool); pool -= cw; left = cw
        order = sorted(tasks, key=lambda t: t["kind"] != "hall")
        for t in tasks: t["w"] = 0
        for _ in range(cfg["max_workers_per_scaffold"]):
            for t in order:
                if left and t["w"] < cfg["max_workers_per_scaffold"]: t["w"] += 1; left -= 1
        idle_cw += left
        for b in blds:
            if b["type"] == "farm" and rescue: continue
            n = min(cfg["buildings"][b["type"]]["capacity"], pool); b["w"] += n; pool -= n
        free = pool
        say("   people %d: construct %d, free %d | workers: %s" % (people, cw - left, free,
            ", ".join("%s%d" % (b["type"], b["w"]) for b in blds if b["w"]) or "none on buildings"))
        # 5. earn
        raws = {}; p = {}
        for r in R:
            raw = persona["mean"] if persona["sd"] == 0 else min(2.0, max(0.0, rnd.gauss(persona["mean"], persona["sd"])))
            raws[r] = raw; p[r], bite = progress(cfg, raw); capdays += bite
        inc = {}
        for r in R:
            base = cfg["sources"][r]["base"]; add = 0; mult = 1.0
            for b in blds:
                d = cfg["buildings"][b["type"]]
                if d.get("produces") == r: add += d["add"]; mult *= b["pw"] ** b["w"]
            inc[r] = (base + add) * p[r] * mult; wallet[r] += inc[r]
            fill = base * p[r] * cfg["assemble"]
            for t in tasks:
                if r in t["bars"]:
                    bar = t["bars"][r]; bar[0] = min(bar[1], bar[0] + fill * curve(cfg, t["w"]))
        say("   rings: " + " ".join("%s %d%%" % (RING[r], raws[r] * 100) for r in R))
        say("   earned: " + " ".join("%s +%.1f" % (r, inc[r]) for r in R))
        for t in tasks:
            if all(v[0] >= v[1] for v in t["bars"].values()):
                t["ready"] = True
            say("   scaffold %-22s workers %d  %s%s" % (t["label"], t["w"], " ".join("%s %d%%" % (r[0], 100 * v[0] / v[1]) for r, v in t["bars"].items()), "  READY" if t["ready"] else ""))
        # 6. eat
        eat = people * fpd; wallet["food"] -= eat; prev_hungry = False
        if wallet["food"] < 0: wallet["food"] = 0; hungry += 1; prev_hungry = True
        say("   ate %d food%s | stock %s" % (eat, " (HUNGRY)" if prev_hungry else "", " ".join("%s %d" % (r, wallet[r]) for r in R)))
    return {"mil": mil, "wallet": wallet, "people": people, "hungry": hungry, "rescue": rescue_days, "capdays": capdays,
            "blocked": st, "idle_cw": idle_cw, "hall": hall_lv}

def avg(xs): return sum(xs) / len(xs) if xs else None

def main():
    cfg = json.load(open("data.json"))
    if "--log" in sys.argv:
        a = sys.argv[sys.argv.index("--log") + 1:]
        lines = []; run(cfg, cfg["players"][a[0]], cfg["templates"][a[1]], 1, lines)
        n = int(a[2]) if len(a) > 2 else 5
        out = []; d = 0
        for l in lines:
            if l.startswith("== day"): d += 1
            if d > n: break
            out.append(l)
        print("\n".join(out)); return
    N = cfg["seeds"]
    print("days %d, seeds %d, cap %s, overflow %s, food rescue %s\n" % (cfg["days"], N, cfg["cap"], cfg["overflow"]["enabled"], cfg["food_rescue"]["enabled"]))
    h = "%-8s %-8s %-9s %-9s %-9s %-5s %-6s %-6s %-5s %-24s %s"
    print(h % ("player", "plan", "hall2 day", "hall3 day", "hall4 day", "ppl", "hungry", "rescue", "capD", "end wallet f/w/s/g", "top waits"))
    def d(rs, k):
        v = [r["mil"][k] for r in rs if k in r["mil"]]
        return "%4.1f(%d)" % (avg(v), len(v)) if v else "-"
    for pl, persona in cfg["players"].items():
        for tp, steps in cfg["templates"].items():
            rs = [run(cfg, persona, steps, s) for s in range(1, (1 if persona["sd"] == 0 else N) + 1)]
            w = {r: avg([x["wallet"][r] for x in rs]) for r in cfg["sources"]}
            bl = Counter()
            for x in rs: bl.update(x["blocked"])
            top = ", ".join("%s:%d" % (k, v / len(rs)) for k, v in bl.most_common(3))
            print(h % (pl, tp, d(rs, "hall2"), d(rs, "hall3"), d(rs, "hall4"), "%.0f" % avg([x["people"] for x in rs]), "%.0f" % avg([x["hungry"] for x in rs]),
                       "%.0f" % avg([x["rescue"] for x in rs]), "%.0f" % avg([x["capdays"] for x in rs]),
                       "%d/%d/%d/%d" % (w["food"], w["wood"], w["stone"], w["gold"]), top))
    print("\n(n) = seeds that reached it. Waits are average days per run.")
main()

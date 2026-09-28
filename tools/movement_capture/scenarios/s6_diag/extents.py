"""Lane extents around the street pawn (2391.7, -266): for every recording made at a street* mark, the hero's world
displacement path (camera displacement at fixed yaw = hero displacement). Prints, per 15-deg world-direction sector,
the farthest radius reached and by which recording, plus low-altitude (z < 40) radius. Usage: extents.py"""
import os, glob, json, math, numpy as np, csv
MC = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
best = {}
for meta_p in glob.glob(os.path.join(MC, "rec_auto", "*", "*", "*_inputs.json")) + glob.glob(os.path.join(MC, "rec_auto", "*", "*_inputs.json")):
    try:
        meta = json.load(open(meta_p))
    except Exception:
        continue
    mv = meta.get("mark_value", {})
    pawn = mv.get("pawn")
    if not pawn or math.hypot(pawn[0] - 2391.7, pawn[1] + 266.0) > 5:
        continue
    p = meta_p[:-len("_inputs.json")] + ".csv"
    if not os.path.exists(p):
        continue
    r = [x for x in csv.DictReader(open(p)) if x.get("valid", "1") == "1" and x["pos_x"]]
    if len(r) < 10:
        continue
    P = np.array([[float(x["pos_x"]), float(x["pos_y"]), float(x["pos_z"])] for x in r]); P -= P[0]
    name = os.path.relpath(p, os.path.join(MC, "rec_auto")).replace("\\", "/") + "@" + meta.get("mark", "?")
    ang = np.degrees(np.arctan2(P[:, 1], P[:, 0])) % 360
    rad = np.hypot(P[:, 0], P[:, 1])
    for lowonly in (False, True):
        m = (P[:, 2] < 40) if lowonly else np.ones(len(P), bool)
        for a, rr in zip(ang[m], rad[m]):
            k = (int(a // 15), lowonly)
            if rr > best.get(k, (0, ""))[0]:
                best[k] = (rr, name)
for s in range(24):
    a, b = best.get((s, False), (0, "-")), best.get((s, True), (0, "-"))
    print("world %3d-%3d: max r %5.0f (%s)   low r %5.0f (%s)" % (s * 15, s * 15 + 15, a[0], a[1], b[0], b[1]))

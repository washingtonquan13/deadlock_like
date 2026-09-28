"""Copy each scenario with start.yaw_deg = the game view yaw, replay in the sim, compare with the game.
Usage: run.py TAG [NAME...]  -> _out/<TAG>_<NAME>.csv.  Game-sim alignment: shift the game so the air-jump HUD step
(first rise >100 after tick 50) lines up with the sim's.  Prints: HUD at +2, apex HUD minimum, and camera fwd/left
(start-yaw frame) at +20/+40 after the step, sim vs game trial means."""
import sys, os, json, glob, subprocess, math, csv, numpy as np
H = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.abspath(os.path.join(H, "..", "..", "..", ".."))
G = "D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
SRC = {"DRWA": "s6_diag", "DRWDY": "s6_diag", "DRSA": "s6_diag", "DRD": "s6_diag", "DRA": "s6_diag", "DWA": "s6_diag", "DBSA": "s6_diag",
       "DRWDR": "s6_diag", "DGRWD": "double", "DGRSD": "double", "DGWD": "double", "DGBSD": "double", "DGBSA": "double",
       "DBL": "double", "DBW16": "double", "DBRW": "double", "DBX": "double", "R1": "route"}
tag = sys.argv[1]; names = sys.argv[2:] or list(SRC)
os.makedirs(os.path.join(H, "_out"), exist_ok=True)
def step(t, v, tmin=50):
    d = np.diff(np.r_[v[0], v]); j = np.where((t > tmin) & (d > 100))[0]; return t[j[0]] if len(j) else None
for n in names:
    d = SRC[n]; rec = sorted(glob.glob(os.path.join(ROOT, "tools/movement_capture/rec_auto", d, n, "*_t[0-9].csv")))
    rows = [[r for r in csv.DictReader(open(p)) if r["valid"] == "1" and r["vel_scalar"] and r["pos_x"]] for p in rec]
    yaw = float(rows[0][0]["ang_yaw"])
    sc = json.load(open(os.path.join(ROOT, "tools/movement_capture/scenarios", d, n + ".json")))
    tpl = json.load(open(os.path.join(ROOT, "tools/movement_capture/scenarios/s6_diag/DRWDY.json")))
    for k in ("hero", "suppress_sprint", "params"): sc.setdefault(k, tpl[k])
    sc["start"].setdefault("sprint_on", True)
    sc["start"]["yaw_deg"] = yaw
    sp = os.path.join(H, "_out", "%s.json" % n); json.dump(sc, open(sp, "w"), indent=1)
    out = os.path.join(H, "_out", "%s_%s.csv" % (tag, n))
    rel = lambda p: os.path.relpath(p, ROOT).replace("\\", "/")
    subprocess.run([G, "--headless", "--path", ROOT, "-s", "res://tools_fit/route_export.gd", "--", "--scenario=res://" + rel(sp), "--out=" + rel(out)],
                   cwd=ROOT, capture_output=True)
    S = np.genfromtxt(out, delimiter=",", names=True, dtype=None, encoding=None)
    st, sv, sf, sl = S["tick"].astype(float), S["speed3d"], S["fwd"], S["left"]
    tmin = 130 if n == "R1" else 50
    s0 = step(st, sv, tmin); y = math.radians(yaw)
    res = []
    for r in rows:
        t = np.array([float(x["t"]) for x in r]) * 64 + 1; v = np.array([float(x["vel_scalar"]) for x in r])
        P = np.array([[float(x["pos_x"]), float(x["pos_y"])] for x in r]); P -= P[0]
        f = P[:, 0] * math.cos(y) + P[:, 1] * math.sin(y); l = -P[:, 0] * math.sin(y) + P[:, 1] * math.cos(y)
        g0 = step(t, v, tmin);
        if g0 is None: continue
        t = t - g0 + s0
        m = (t > s0 + 15) & (t < s0 + 55)
        mn = v[m].min() if m.any() else np.nan
        # displacement from the step
        ft = lambda k: (np.interp(s0 + k, t, f) - np.interp(s0, t, f), np.interp(s0 + k, t, l) - np.interp(s0, t, l))
        res.append((np.interp(s0 + 3, t, v), mn, *ft(20), *ft(40), t[-1]))
    res = np.array(res)
    m = (st > s0 + 15) & (st < s0 + 55)
    sd = lambda k: (np.interp(s0 + k, st, sf) - np.interp(s0, st, sf), np.interp(s0 + k, st, sl) - np.interp(s0, st, sl))
    simr = (np.interp(s0 + 3, st, sv), sv[m].min(), *sd(20), *sd(40))
    gm = res[:, :6].mean(0); lim = res[:, 6].min() - s0
    print("%-6s yaw %6.2f | HUD+3 %5.0f/%5.0f  apexmin %5.1f/%5.1f (%+5.1f) | +20 f %5.0f/%5.0f l %5.0f/%5.0f | +40 f %5.0f/%5.0f l %5.0f/%5.0f (%+4.0f) %s" % (
        n, yaw, simr[0], gm[0], simr[1], gm[1], simr[1] - gm[1], simr[2], gm[2], simr[3], gm[3], simr[4], gm[4], simr[5], gm[5], simr[5] - gm[5],
        "" if lim >= 40 else "(game ends +%d)" % lim))

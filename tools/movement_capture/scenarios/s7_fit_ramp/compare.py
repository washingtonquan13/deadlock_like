"""s7 ramp: game vs sim summary (run from tools/movement_capture): compare.py TAG [TAG...]
Per scenario: peak horizontal speed (HUD) and its time, last-move time, end distance along the start facing,
plus for the sim the biggest one-tick drop of horizontal speed on the way down (a 'speed teleport')."""
import sys, os, glob, csv
os.environ["MARK"] = "ramp1_top"
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "s7_ramp"))
import ana
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", "tools_fit", "_out", "s7_ramp")
SC = ["RWALK", "RBOT", "RRUN", "RDASH", "RJ", "RSWtop", "RUP"]
def game(s):
    os.environ["MARK"] = "ramp1_bot" if s == "RUP" else "ramp1_top"
    import importlib; importlib.reload(ana.A); importlib.reload(ana)
    r = [ana.summary(p) for p in sorted(glob.glob("rec_auto/s7_ramp/%s/*.csv" % s))]
    return {k: float(np.median([x[k] for x in r])) for k in ("peak", "t_peak", "t_stop", "d_end")}
def sim(tag, s):
    p = os.path.join(OUT, "%s_%s.csv" % (tag, s))
    if not os.path.exists(p): return None
    rows = list(csv.DictReader(open(p)))
    t = np.array([float(r["t"]) for r in rows]); v = np.array([float(r["speed_h"]) for r in rows])
    d = np.array([float(r["fwd"]) for r in rows])
    mv = np.where(v > 1.0)[0]; k = int(np.argmax(v))
    dv = np.diff(v); j = int(np.argmin(dv))
    return dict(peak=v[k], t_peak=t[k], t_stop=t[mv[-1]] if len(mv) else np.nan, d_end=d[-1], drop=-dv[j], t_drop=t[j + 1])
tags = sys.argv[1:]
print("%-7s %-8s %6s %6s %6s %6s %s" % ("scn", "who", "peak", "t_pk", "t_stop", "d_end", "max 1-tick drop"))
for s in SC:
    g = game(s)
    print("%-7s %-8s %6.0f %6.2f %6.2f %6.0f" % (s, "game", g["peak"], g["t_peak"], g["t_stop"], g["d_end"]))
    for tg in tags:
        m = sim(tg, s)
        if m: print("%-7s %-8s %6.0f %6.2f %6.2f %6.0f   %5.0f @ %.2f" % (s, tg, m["peak"], m["t_peak"], m["t_stop"], m["d_end"], m["drop"], m["t_drop"]))

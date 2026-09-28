"""Takeoff ratio h0 / v_ground(t0 - 1): the ground HUD trend (J-6..J+0.2) extrapolated to one tick before the fitted
air-state display time t0 (= the last ground state shown). Walk jumps calibrate the method (expect ~1.00)."""
import sys, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from load import load, trials
from fitsj import fit_trial
out = {}
for st, nm, J in [("hop", "BHP2", 40), ("hop", "BHP8", 40), ("hop", "BHH", 40), ("air", "A0", 40), ("air", "AW", 40),
                  ("hop", "SHJ3", 27), ("hop", "SHJ10", 34), ("hop", "SHJ19", 43), ("hop", "SHJ19R", 43), ("hop", "SHJ19P", 43),
                  ("hop", "SHJ40", 64), ("hop", "SHJ60", 84)]:
    for p in trials(st, nm):
        f = fit_trial(p, J); tk, sp, _ = load(p)
        g = (tk >= J - 6) & (tk <= J + 0.2); c = np.polyfit(tk[g], sp[g], 1)
        vr = np.polyval(c, f["t0"] - 1.0)
        flat = f["T"] > 44.5
        h0 = f["h0"] if flat else f["h0_apex"]
        out.setdefault(nm, []).append(h0 / vr)
        print("%-7s %s  v_ground %5.1f (slope %5.2f/tick)  h0 %5.1f %-6s  ratio %.3f" % (nm, p[-10:-4], vr, c[0], h0, "pinned" if flat else "apex", h0 / vr))
for k, v in out.items(): print("%-7s mean ratio %.3f" % (k, np.mean(v)))
sl = [x for k in ("SHJ3", "SHJ10", "SHJ19", "SHJ19R", "SHJ19P", "SHJ40", "SHJ60") for x in out[k]]
wk = [x for k in ("BHP2", "BHP8", "BHH", "A0", "AW") for x in out[k]]
print("dash-slide jumps: n %d mean %.3f sd %.3f   walk jumps: n %d mean %.3f sd %.3f   slide/walk %.3f" % (
    len(sl), np.mean(sl), np.std(sl), len(wk), np.mean(wk), np.std(wk), np.mean(sl) / np.mean(wk)))

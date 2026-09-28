"""Dash-slide jump cut: h0 (pinned fit, or apex method where the landing is not flat) vs the pre-jump ground HUD.
Reference speeds: vlast = last display sample >= 1 tick before the fitted t0 (the last ground state shown);
vJ = ground trend evaluated at the press tick J. Fits h0 = a*v and h0 = a*v + b."""
import sys, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from load import load, trials
from fitsj import fit_trial
rows = []
for nm, J in [("SHJ3", 27), ("SHJ10", 34), ("SHJ19", 43), ("SHJ19R", 43), ("SHJ19P", 43), ("SHJ40", 64), ("SHJ60", 84)]:
    for p in trials("hop", nm):
        f = fit_trial(p, J); tk, sp, _ = load(p)
        i = np.where(tk <= f["t0"] - 1.0)[0][-1]
        flat = f["T"] > 44.5
        h0 = f["h0"] if flat else f["h0_apex"]
        rows.append((nm, p[-10:-4], J, tk[i], sp[i], f["vgJ"], h0, flat))
        print("%-7s %s J%3d  last ground sample t%6.1f HUD %5.1f  vJ %5.1f  h0 %5.1f (%s)  h0/vlast %.3f  h0/vJ %.3f  drop %5.1f" % (
            nm, p[-10:-4], J, tk[i], sp[i], f["vgJ"], h0, "pinned" if flat else "apex", h0 / sp[i], h0 / f["vgJ"], sp[i] - h0))
v = np.array([r[4] for r in rows]); h = np.array([r[6] for r in rows])
a = np.sum(v * h) / np.sum(v * v); print("h0 = a*vlast: a %.4f rms %.2f" % (a, np.sqrt(np.mean((a * v - h) ** 2))))
c = np.polyfit(v, h, 1); print("h0 = a*vlast + b: a %.4f b %.1f rms %.2f" % (c[0], c[1], np.sqrt(np.mean((np.polyval(c, v) - h) ** 2))))
m = np.array([r[0] != "SHJ3" for r in rows])
a2 = np.sum(v[m] * h[m]) / np.sum(v[m] ** 2); print("excluding SHJ3: a %.4f rms %.2f" % (a2, np.sqrt(np.mean((a2 * v[m] - h[m]) ** 2))))

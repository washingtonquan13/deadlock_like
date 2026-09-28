"""h(s) = sqrt(HUD^2 - vz^2), vz = G*T/2 - G*s, per scenario (first trial of each, binned per 2 ticks) vs exp(-0.2 s).
Usage: hshape.py"""
import sys, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import hopfit7 as H
for n in ["SHH6", "SHH12", "SHH20", "SHH30", "SHH40"]:
    rows = []
    for t0, t1, hg, s, sp in H.D[n]:
        vz = (H.VZ0 or H.G * (t1 - t0) / 128) - H.G * s
        h = np.sqrt(np.maximum(sp ** 2 - vz ** 2, 0))
        rows.append((s * 64, h / hg / np.exp(-0.2 * s) if len(sys.argv) < 2 else h))
    out = []
    for b in range(0, 46, 2):
        v = [np.mean(r[1][(r[0] >= b) & (r[0] < b + 2)]) for r in rows if np.any((r[0] >= b) & (r[0] < b + 2))]
        out.append("%d:%.3f" % (b, np.mean(v)) if v else "%d:-" % b)
    print(n, " ".join(out))

"""Raw HUD around the air jump and h = sqrt(HUD^2 - vz^2) with vz pinned: vz = VZ - g*(tick - tj), tj = first HUD step.
Usage: hudraw.py A B DIR...  (prints ticks A..B)"""
import sys, numpy as np
sys.path.insert(0, __import__("os").path.dirname(__file__))
from ana import load
A, B = int(sys.argv[1]), int(sys.argv[2]); G, VZ = 796.0, 522.0
for d in sys.argv[3:]:
    for tr in load(d):
        t, h = tr["t"], tr["hud"]
        m = (t >= A) & (t <= B)
        j = np.where(m & (np.diff(np.r_[h[0], h]) > 150))[0]
        tj = t[j[0]] if len(j) else float("nan")
        print("%s  step at tick %.2f (HUD %.0f -> %.0f)" % (tr["name"], tj, h[j[0] - 1] if len(j) else 0, h[j[0]] if len(j) else 0))
        row = []
        for i in np.where(m)[0]:
            vz = VZ - G * (t[i] - tj) / 64.0
            hh = np.sqrt(max(h[i] ** 2 - vz ** 2, 0)) if t[i] >= tj else float("nan")
            row.append("%.1f:%.0f/%s" % (t[i], h[i], "-" if np.isnan(hh) else "%.0f" % hh))
        print("   " + "  ".join(row))

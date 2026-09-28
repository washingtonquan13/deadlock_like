import sys, csv
import numpy as np
p, a, b = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
prev = None
for r in R:
    t = float(r["t"])
    if a <= t <= b:
        P = np.array([float(r["pos_x"]), float(r["pos_y"]), float(r["pos_z"])])
        d = (P - prev) if prev is not None else P * 0
        print("%.3f tick %5.1f  pos %8.1f %8.1f %7.1f  d %5.1f %5.1f %5.1f  hud %s  pitch %s yaw %s" % (t, t * 64 + 1, *P, *d, r["vel_scalar"], r["ang_pitch"], r["ang_yaw"]))
        prev = P

"""Tick series: HUD speed, camera z (relative), horizontal distance from the start. Usage: ser.py A B CSV..."""
import sys, csv, numpy as np
A, B = float(sys.argv[1]), float(sys.argv[2])
for p in sys.argv[3:]:
    r = [x for x in csv.DictReader(open(p)) if x["valid"] == "1" and x["pos_z"] and x["vel_scalar"]]
    t = np.array([float(x["t"]) for x in r]) * 64 + 1
    P = np.array([[float(x["pos_x"]), float(x["pos_y"]), float(x["pos_z"])] for x in r]); P -= P[0]
    sp = np.array([float(x["vel_scalar"]) for x in r])
    print(p); row = []
    for i in np.where((t >= A) & (t <= B))[0][::2]:
        row.append("%5.1f %5.0f z%5.1f d%5.1f" % (t[i], sp[i], P[i, 2], np.hypot(P[i, 0], P[i, 1])))
        if len(row) == 4: print("  " + " | ".join(row)); row = []
    if row: print("  " + " | ".join(row))

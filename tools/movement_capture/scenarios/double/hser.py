"""Horizontal velocity (fwd, lat) around the air jump from camera position: slope over +-3 ticks.
Usage: hser.py YAW A B CSV...   (street_y148 yaw 148; ticks A..B step 2). Camera, so +-30 u/s noise."""
import sys, os, numpy as np, csv, math
yaw = math.radians(float(sys.argv[1])); A, B = int(sys.argv[2]), int(sys.argv[3])
fx, fy = math.cos(yaw), math.sin(yaw)
for p in sys.argv[4:]:
    r = list(csv.DictReader(open(p)))
    t = np.array([float(x["t"]) for x in r]) * 64 + 1
    r = [x for x in r if x.get("valid", "1") == "1" and x["vel_scalar"] and x["pos_x"]]; t = np.array([float(x["t"]) for x in r]) * 64 + 1
    P = np.array([[float(x["pos_x"]), float(x["pos_y"]), float(x["pos_z"])] for x in r])
    hud = np.array([float(x["vel_scalar"]) for x in r])
    print(p)
    for k in range(A, B + 1, 2):
        m = np.abs(t - k) <= 3
        if m.sum() < 4: continue
        tt = t[m] / 64
        vx = np.polyfit(tt, P[m, 0], 1)[0]; vy = np.polyfit(tt, P[m, 1], 1)[0]; vz = np.polyfit(tt, P[m, 2], 1)[0]
        f = vx * fx + vy * fy; l = -vx * fy + vy * fx
        print("  %3d hud %4.0f fwd %5.0f lat %5.0f h %4.0f vz %5.0f" % (k, np.interp(k, t, hud), f, l, math.hypot(f, l), vz))

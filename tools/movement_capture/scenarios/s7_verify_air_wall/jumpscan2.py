"""Verifier: windowed (~4 tick) camera 3D speed vs HUD speed. Camera moves in 3D and HUD is 3D |v|, so on a ground
slope they should agree (up to boom lag at yaw-constant). Flags windows with speed > 1.3*HUD+60 u/s."""
import glob, os, csv
import numpy as np
root = "rec_auto/s7_ramp"; W = 4 / 64
for clip in sorted(os.listdir(root)):
    for p in sorted(glob.glob(os.path.join(root, clip, "*.csv"))):
        R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
        t = np.array([float(r["t"]) for r in R]); P = np.array([[float(r["pos_x"]), float(r["pos_y"]), float(r["pos_z"])] for r in R])
        hud = np.array([float(r["vel_scalar"]) if r["vel_scalar"] else np.nan for r in R])
        flags = []; ratios = []
        for i in range(len(t)):
            j = np.searchsorted(t, t[i] + W)
            if j >= len(t) or t[i] < 0: continue
            v = np.linalg.norm(P[j] - P[i]) / (t[j] - t[i]); h = np.nanmax(hud[i:j + 1])
            if h > 100: ratios.append(v / h)
            if v > 1.3 * h + 60: flags.append((t[i], t[j], v, h, *(P[j] - P[i])))
        # merge consecutive flags
        ev = []
        for f in flags:
            if ev and f[0] <= ev[-1][1]: ev[-1] = (ev[-1][0], f[1], max(ev[-1][2], f[2]), f[3], *f[4:])
            else: ev.append(f)
        print("%-7s %-12s ratio cam/HUD med %.3f  events %d" % (clip, os.path.basename(p), np.median(ratios) if ratios else 0, len(ev)))
        for e in ev: print("     t %.3f-%.3f  cam %.0f u/s  hud %.0f  last d(%.1f %.1f %.1f)" % e)

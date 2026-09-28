"""Wall-jump kick with the key pressed on the jump tick only (s9_open WK_*, mark wallAd): horizontal velocity from
linear fits of the HUD position before the wall (1.05-1.30 s) and in flight after it (windows below)."""
import csv, glob, sys
import numpy as np
WIN = [(1.05, 1.30), (1.50, 1.70), (1.65, 1.90), (1.85, 2.10)]
for s in sys.argv[1:] or ["WK_N", "WK_A", "WK_D", "WK_WA", "WK_SA"]:
    for p in sorted(glob.glob("rec_auto/s9_open/%s/ts1_t?.csv" % s)):
        R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
        t, x, y, z = (np.array([float(r[k]) for r in R]) for k in ("t", "pos_x", "pos_y", "pos_z"))
        out = []
        for a, b in WIN:
            m = (t > a) & (t < b)
            if m.sum() < 4:
                out.append("     --     ")
                continue
            vx, vy, vz = (np.polyfit(t[m], q[m], 1)[0] for q in (x, y, z))
            out.append("%5.0f %4.0f %4.0f" % (vx, vy, vz))
        print("%-5s %s n=%3d  %s" % (s, p[-6:-4], len(R), " | ".join(out)))

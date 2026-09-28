"""Verifier: scan s7_ramp game recordings for camera position jumps not explained by HUD speed.
Uses raw valid rows (camera pos), no mark offsets. Flags a row pair where |dpos|/dt exceeds HUD*1.5+150 u/s
AND |dpos| > 4 u. Also prints camera z profile steppiness: fraction of dz between valid rows that is ~0 while moving."""
import glob, os, sys, csv
import numpy as np
root = "rec_auto/s7_ramp"
for clip in sorted(os.listdir(root)):
    for p in sorted(glob.glob(os.path.join(root, clip, "*.csv"))):
        R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
        t = np.array([float(r["t"]) for r in R]); P = np.array([[float(r["pos_x"]), float(r["pos_y"]), float(r["pos_z"])] for r in R])
        hud = np.array([float(r["vel_scalar"]) if r["vel_scalar"] else np.nan for r in R])
        dt = np.diff(t); dp = np.linalg.norm(np.diff(P, axis=0), axis=1); v = dp / np.maximum(dt, 1e-6)
        hm = np.fmax(hud[1:], hud[:-1])
        bad = np.where((v > 1.5 * hm + 150) & (dp > 4) & (t[1:] > 0))[0]
        # vertical smoothness while moving on the slope: dz per row vs horizontal
        dz = np.diff(P[:, 2]); dh = np.linalg.norm(np.diff(P[:, :2], axis=0), axis=1)
        mv = (dh > 1.0) & (np.abs(dz) > 0.3)
        ratio = np.abs(dz[mv]) / dh[mv] if mv.any() else np.array([0])
        print("%-7s %s rows %d  jumps %d  |dz|/dh on slope: med %.3f p10 %.3f p90 %.3f max %.2f" % (clip, os.path.basename(p), len(R), len(bad),
              np.median(ratio), np.percentile(ratio, 10), np.percentile(ratio, 90), ratio.max()))
        for i in bad[:6]:
            print("     t %.3f->%.3f dt %.4f  dpos %.1f (dx %.1f dy %.1f dz %.1f)  v %.0f  hud %.0f/%.0f" % (t[i], t[i+1], dt[i], dp[i], *(P[i+1]-P[i]), v[i], hud[i], hud[i+1]))

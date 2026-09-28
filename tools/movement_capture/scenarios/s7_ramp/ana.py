"""s7_ramp analysis (run from tools/movement_capture): ana.py DIR [MARK] [step]
Hero track = HUD camera with the mark's camera offset rotated by the yaw change (see scenarios/wall/analyze.py).
Prints per trial: time, HUD speed, distance along the mark facing d (u), camera z rel. to start (u),
horizontal speed from positions (u/s), vz from positions (u/s). Summary: peak HUD, t of peak, stop time/place."""
import sys, os, glob
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "wall"))
os.environ.setdefault("MARK", sys.argv[2] if len(sys.argv) > 2 else "ramp1_top")
import analyze as A
def load(p):
    t, fwd, lat, z, sp, yaw = A.track(p)
    ok = np.isfinite(fwd) & np.isfinite(z)
    return t[ok], fwd[ok], lat[ok], z[ok], sp[ok]
def dv(t, q, w=0.047):
    out = np.full(len(t), np.nan)
    for i in range(len(t)):
        j0, j1 = np.searchsorted(t, t[i] - w), min(np.searchsorted(t, t[i] + w), len(t) - 1)
        if j1 > j0 and t[j1] > t[j0]: out[i] = (q[j1] - q[j0]) / (t[j1] - t[j0])
    return out
def summary(p):
    t, d, lat, z, sp = load(p)
    k = int(np.nanargmax(sp)); mv = np.where(sp > 1.0)[0]
    stop = t[mv[-1]] if len(mv) else float("nan")
    return dict(peak=sp[k], t_peak=t[k], d_peak=d[k], t_stop=stop, d_end=d[-1], lat_end=lat[-1], z_end=z[-1], zmin=z.min())
if __name__ == "__main__":
    step = float(sys.argv[3]) if len(sys.argv) > 3 else 0.1
    for p in sorted(glob.glob(os.path.join(sys.argv[1], "*.csv"))):
        t, d, lat, z, sp = load(p); vh = np.hypot(dv(t, d), dv(t, lat)); vz = dv(t, z)
        s = summary(p)
        print("== %s  peak %.1f @ %.2fs (d %.0f)  last move %.2fs  end d %.0f lat %.0f z %.0f" % (
            os.path.basename(p), s["peak"], s["t_peak"], s["d_peak"], s["t_stop"], s["d_end"], s["lat_end"], s["z_end"]))
        if step > 0:
            print("    t    hud      d     lat      z     vh     vz")
            for tt in np.arange(0, t[-1], step):
                i = min(np.searchsorted(t, tt), len(t) - 1)
                print("%5.2f %6.1f %6.0f %7.1f %6.1f %6.0f %6.0f" % (t[i], sp[i], d[i], lat[i], z[i], vh[i], vz[i]))

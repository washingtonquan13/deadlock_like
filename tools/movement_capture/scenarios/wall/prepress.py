"""Velocity just before the wall-jump press (quadratic fit over [press-WIN, press]) and after (fitwj model)."""
import sys, glob, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from analyze import track
TP = float(os.environ["TPRESS"]); WIN = float(os.environ.get("WIN", "0.12"))
for d in sys.argv[1:]:
    for p in sorted(glob.glob(os.path.join(d, "*.csv"))):
        t, fwd, lat, z, sp, yaw = track(p)
        m = (t > TP - WIN) & (t <= TP + 1 / 64)
        tau = t[m] - TP
        vs = [np.polyfit(tau, q[m], 2)[1] for q in (fwd, lat, z)]
        i = np.searchsorted(t, TP)
        print("%-5s %s pre-press v_fwd %6.1f v_lat %6.1f v_z %6.1f  hud_sp %.1f  z %.2f m" % (os.path.basename(d), p[-10:-4], *vs, sp[i - 1], z[i - 1] * .0254))

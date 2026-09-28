"""Horizontal dash-jump launch speed from the HUD: vz(t) = vz0 - 800 tau, h(t) = sqrt(hud^2 - vz^2) fitted as
h0 * exp(-0.2 tau) (air drag 0.2/s, no key held). vz0 and the takeoff time come from the height track."""
import sys, os, glob, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "wall"))
from analyze import track
for d in sys.argv[1:]:
    for p in sorted(glob.glob(os.path.join(d, "*.csv"))):
        t, f, l, z, sp, yaw = track(p)
        up = np.where(z > 1.5)[0]
        if not len(up): continue
        i0 = up[0]; j = i0
        while j + 1 < len(z) and z[j + 1] > 1.5: j += 1
        t0 = t[i0]
        m = (t > t0) & (t < t0 + 0.3) & np.isfinite(z)
        tau = t[m] - t0
        c = np.polyfit(tau, z[m] + 400 * tau ** 2, 1)   # z + 400 tau^2 = z0 + vz0 tau
        vz0 = c[0]
        # the first frame above 1.5 u is ~z/vz after the real takeoff: shift
        tk = t0 - c[1] / vz0
        mm = (t > t0 + 0.02) & (t < t[j] - 0.04) & np.isfinite(sp)
        tau = t[mm] - tk
        vz = vz0 - 800 * tau
        h = np.sqrt(np.maximum(sp[mm] ** 2 - vz ** 2, 0))
        h0 = np.exp(np.mean(np.log(h) + 0.2 * tau))
        print("%-5s %s  vz0 %5.1f  h0 %5.1f  (residual rms %.1f)" % (os.path.basename(d), p[-6:-4], vz0, h0, np.sqrt(np.mean((h - h0 * np.exp(-0.2 * tau)) ** 2))))

"""Air-jump vz from the HUD 3D speed: vz = sqrt(sp^2 - h^2), h = horizontal speed from track (median over the
first 0.15 s after the jump). Fits vz(t) = v0 - g (t - tj) over 0.05..0.35 s after the press; also apex rise.
Usage: MARK=street vzfit.py K CSV..."""
import sys, os, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "wall"))
from analyze import track
k = int(sys.argv[1])
for p in sys.argv[2:]:
    t, f, l, z, sp, yaw = track(p)
    up = np.where(z > 1.0)[0]; tg = t[up[0]] - 1.0 / 64; tj = tg + k / 64
    def hv(a, b):
        m = (t > a) & (t < b); A = np.vstack([t[m], np.ones(m.sum())]).T
        vf = np.linalg.lstsq(A, f[m], rcond=None)[0][0]; vl = np.linalg.lstsq(A, l[m], rcond=None)[0][0]
        return vf, vl
    vf0, vl0 = hv(tj - 0.15, tj - 0.01); vf1, vl1 = hv(tj + 0.05, tj + 0.35)
    m = (t > tj + 0.05) & (t < tj + 0.35) & np.isfinite(sp)
    h = np.hypot(vf1, vl1); vz = np.sqrt(np.maximum(sp[m] ** 2 - h ** 2, 0))
    g, v0 = np.polyfit(t[m] - tj, vz, 1)
    zj = np.interp(tj, t, z); apex = np.nanmax(z[t > tj])
    print("%s  before vf %5.0f vl %5.0f | after vf %5.0f vl %5.0f | vz0 %5.0f g %5.0f | rise to apex %5.1f" % (
        p.split("double/")[1], vf0, vl0, vf1, vl1, v0, -g, apex - zj))

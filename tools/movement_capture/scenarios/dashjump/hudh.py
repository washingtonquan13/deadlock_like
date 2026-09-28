"""Horizontal speed from the HUD speed readout (3D) and the height track: h = sqrt(sp^2 - vz^2), vz from a local
z slope. Camera-derived horizontal positions are unreliable during dashes (the camera shifts vs the hero)."""
import sys, os, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "wall"))
from analyze import track
TD = 3 / 64
step = float(os.environ.get("STEP", 0.05))
for p in sys.argv[1:]:
    t, f, l, z, sp, yaw = track(p)
    print(p)
    for tt in np.arange(0.0, t[-1], step):
        a = (t > tt - 0.02) & (t < tt + 0.02) & np.isfinite(z)
        if a.sum() < 3: continue
        vz = np.polyfit(t[a], z[a], 1)[0]
        s = np.nanmedian(sp[a])
        h = np.sqrt(max(s * s - vz * vz, 0))
        print("  t %.2f (dash+%.2f)  hud %6.1f  vz %6.1f  h %6.1f  z %5.1f" % (tt, tt - TD, s, vz, h, np.nanmean(z[a])))

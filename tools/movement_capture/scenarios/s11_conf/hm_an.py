"""Heavy melee: HUD speed profile from the lunge onset, and settled displacement (camera lag cancels once at rest)."""
import sys, os, glob, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "wall"))
from analyze import track
for name in sys.argv[1:]:
    print("##", name)
    for p in sorted(glob.glob("rec_auto/s11_conf/%s/*.csv" % name)):
        t, f, l, z, sp, yaw = track(p)
        t0 = float(os.environ.get("T0", 0.3))
        i = np.where((t > t0) & (np.diff(np.r_[0, sp]) > 150))[0][0]   # HUD jump = lunge onset
        ton = t[i]
        prof = [np.interp(ton + k / 64, t, sp) for k in range(-2, 34, 2)]
        drop = t[np.where((t > ton) & (sp < 0.6 * sp[i + 3]))[0][0]] - ton
        fb = np.interp(ton - 0.05, t, f); fa = np.interp(ton + 0.9, t, f)
        print(" onset %.3f (tick %.1f)  hud/2tick %s  drop@%.3f s  d_fwd(-0.05..+0.9) %.0f u  z %s" % (
            ton, ton * 64 + 1, " ".join("%.0f" % v for v in prof), drop, fa - fb,
            " ".join("%.0f" % (np.interp(ton + k * 0.1, t, z)) for k in range(-2, 9))))

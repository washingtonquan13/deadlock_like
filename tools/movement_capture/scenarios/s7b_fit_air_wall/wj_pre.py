"""WJD/WJA (s7_open): per-frame hero lat/fwd (camera offset rotated out, scenarios/wall/analyze.py track) around the wall
jump, to measure the tangential speed built by the held A/D in the 4 ticks before the kick, and the launch.
Usage (from tools/movement_capture): .venv/Scripts/python.exe scenarios/s7b_fit_air_wall/wj_pre.py WJD WJA"""
import sys, os, glob
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "wall"))
from analyze import track
for n in sys.argv[1:]:
    for p in sorted(glob.glob("rec_auto/s7_open/%s/*.csv" % n)):
        t, fwd, lat, z, sp, yaw = track(p)
        m = (t > 1.28) & (t < 1.50)
        print("==", n, os.path.basename(p))
        for i in np.where(m)[0]:
            print("  t %.4f  rtick %.1f  fwd %8.2f  lat %7.2f  z %7.2f  hud %6.1f" % (t[i], t[i] * 64 + 1, fwd[i], lat[i], z[i], sp[i]))

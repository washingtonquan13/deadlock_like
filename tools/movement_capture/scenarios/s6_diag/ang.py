"""Direction of the camera displacement over tick windows: angle = atan2(left, fwd) in degrees (D-side negative).
Usage: ang.py A B DIR...  (window A..B in CSV ticks)"""
import sys, math, numpy as np
sys.path.insert(0, __import__("os").path.dirname(__file__))
from ana import load, vel, at
A, B = float(sys.argv[1]), float(sys.argv[2])
for d in sys.argv[3:]:
    for tr in load(d):
        vf, vl = vel(tr, A, B, "f"), vel(tr, A, B, "l")
        df, dl = at(tr, B, "f") - at(tr, A, "f"), at(tr, B, "l") - at(tr, A, "l")
        print("%-24s vf %7.1f vl %7.1f |v| %6.1f ang %7.2f  (disp ang %7.2f)  hud %.0f..%.0f" % (tr["name"], vf, vl, math.hypot(vf, vl),
              math.degrees(math.atan2(vl, vf)), math.degrees(math.atan2(dl, df)), at(tr, A, "hud"), at(tr, B, "hud")))

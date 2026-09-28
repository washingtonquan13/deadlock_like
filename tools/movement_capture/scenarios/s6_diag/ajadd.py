"""Air-jump add vector per trial from the camera (fixed yaw): velocity before (ticks tj-10..tj-2) and after
(tj+3..tj+12, drag 0.2/s undone back to tj), tj = HUD step. Prints pre, post, add (size, angle), v.wish after,
and h after from the HUD with vz pinned (VZ 522 at tj+0.5, g 796). Angles: atan2(left, fwd), D side negative.
Usage: ajadd.py WISHANGLE DIR...  (WISHANGLE = expected wish angle in deg, e.g. -45 for W+D, -135 for S+D)"""
import sys, math, numpy as np
sys.path.insert(0, __import__("os").path.dirname(__file__))
from ana import load, vel
W = math.radians(float(sys.argv[1])); wv = np.array([math.cos(W), math.sin(W)])
G, VZ, D = 796.0, 522.0, 0.2
for d in sys.argv[2:]:
    for tr in load(d):
        t, h = tr["t"], tr["hud"]
        j = np.where((t > float(__import__("os").environ.get("TMIN", 50))) & (np.diff(np.r_[h[0], h]) > 100))[0]
        if not len(j):
            print(tr["name"], "no step"); continue
        tj = t[j[0]]
        pre = np.array([vel(tr, tj - 10, tj - 2, k) for k in "fl"])
        post = np.array([vel(tr, tj + 3, tj + 12, k) for k in "fl"]) * math.exp(D * 7.5 / 64)
        add = post - pre
        m = (t >= tj + 3) & (t <= tj + 12)
        vz = VZ - G * (t[m] - tj - 0.5) / 64
        hh = np.sqrt(np.maximum(h[m] ** 2 - vz ** 2, 0)) * np.exp(D * (t[m] - tj) / 64)
        print("%-22s tj %5.1f pre (%6.1f,%6.1f) %5.1f  post (%6.1f,%6.1f) |%5.1f| ang %7.2f  add |%5.1f| ang %7.2f (wish %+.0f)  v.w pre %5.1f post %5.1f  HUD h %5.1f" % (
            tr["name"], tj, pre[0], pre[1], np.hypot(*pre), post[0], post[1], np.hypot(*post), math.degrees(math.atan2(post[1], post[0])),
            np.hypot(*add), math.degrees(math.atan2(add[1], add[0])), math.degrees(W), pre @ wv, post @ wv, np.median(hh)))

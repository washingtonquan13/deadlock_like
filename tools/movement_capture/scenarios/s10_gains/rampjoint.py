"""Joint slope-accel fit: s10 RL* (smooth 26.5 deg ramp1, driver) + s8 city v1..v3 (video OCR).
Windows of 0.2 s: HUD accel, speed, and g*tan(theta) from the z vs path slope. Run from tools/movement_capture."""
import sys, os, glob
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "wall"))
os.environ["MARK"] = "ramp1_slope"
import analyze as A
G = 800.0
X = []  # (gtan, v, acc, tag)
for p in sorted(glob.glob("rec_auto/s10_gains/RL*/*.csv")):
    t, d, lat, z, sp, yaw = A.track(p)
    ok = np.isfinite(sp) & np.isfinite(z) & np.isfinite(d)
    t, d, lat, z, sp = t[ok], d[ok], lat[ok], z[ok], sp[ok]
    s = np.r_[0, np.cumsum(np.hypot(np.diff(d), np.diff(lat)))]
    for tc in np.arange(0.25, 0.76, 0.05):
        m = (t >= tc - 0.1) & (t <= tc + 0.1)
        if m.sum() < 8 or sp[m].min() < 100: continue
        k = -np.polyfit(s[m], z[m], 1)[0]
        if k < 0.42 or k > 0.58: continue   # off the ramp
        X.append((G * k, np.interp(tc, t, sp), np.polyfit(t[m], sp[m], 1)[0], "RL"))
SEG = {1: [(1.05, 1.8)], 2: [(1.55, 2.35)], 3: [(1.0, 2.0)]}
for i, segs in SEG.items():
    a = np.genfromtxt("scenarios/s8_city_slide/ocr/v%d.csv" % i, delimiter=",", names=True)
    P = np.c_[a["x"], a["y"], a["z"]]; t = a["frame"] / 60; v = a["vel"]
    keep = np.r_[True, np.abs(np.diff(P, axis=0)).max(1) > 0]
    P, t, v = P[keep], t[keep], v[keep]
    s = np.r_[0, np.cumsum(np.hypot(*np.diff(P[:, :2], axis=0).T))]
    for t0, t1 in segs:
        for tc in np.arange(t0 + 0.1, t1 - 0.1 + 1e-9, 0.05):
            m = (t >= tc - 0.1) & (t <= tc + 0.1)
            X.append((G * -np.polyfit(s[m], P[m, 2], 1)[0], np.interp(tc, t, v), np.polyfit(t[m], v[m], 1)[0], "v%d" % i))
g = np.array([x[0] for x in X]); v = np.array([x[1] for x in X]); y = np.array([x[2] for x in X]); tag = np.array([x[3] for x in X])
def rep(name, pred):
    r = y - pred
    print("%-44s rms %5.1f | " % (name, np.sqrt(np.mean(r ** 2))) + "  ".join("%s %+5.0f" % (k, r[tag == k].mean()) for k in ("RL", "v1", "v2", "v3")))
rep("sim: g*tan - 0.1875 v", g - 0.1875 * v)
c = np.linalg.lstsq(np.c_[g, -v], y, rcond=None)[0]; rep("K g tan - f v  K %.2f f %.3f" % tuple(c), np.c_[g, -v] @ c)
c = np.linalg.lstsq(np.c_[g, -v, np.ones_like(g)], y, rcond=None)[0]; rep("K g tan - f v + c  %.2f %.3f %.0f" % tuple(c), np.c_[g, -v, np.ones_like(g)] @ c)
M = np.c_[g, -v, g * v / 1000]
c = np.linalg.lstsq(M, y, rcond=None)[0]; rep("K g tan - f v + e g tan v/1000  %.2f %.3f %.2f" % tuple(c), M @ c)
for V in (500, 600, 700, 800, 1000):
    M = np.c_[np.maximum(0, V - v)]
    c = np.linalg.lstsq(M, y - (g - 0.1875 * v), rcond=None)[0]; rep("g tan - .1875v + %.3f*(%d - v)+" % (c[0], V), g - 0.1875 * v + M @ c)
for k in ("RL", "v1", "v2", "v3"):
    m = tag == k
    print(k, "gtan %.0f (%.1f deg)" % (np.median(g[m]), np.degrees(np.arctan(np.median(g[m]) / G))), "v %.0f-%.0f" % (v[m].min(), v[m].max()))
m = tag == "RL"
c = np.polyfit(v[m], y[m], 1); print("RL alone: acc = %.0f %+.3f v  rms %.1f  (g tan %.0f)" % (c[1], c[0], np.std(y[m] - np.polyval(c, v[m])), np.median(g[m])))
for k in ("v1", "v2", "v3"):
    m = tag == k; c = np.polyfit(v[m], y[m], 1); print("%s alone: acc = %.0f %+.3f v  rms %.1f" % (k, c[1], c[0], np.std(y[m] - np.polyval(c, v[m]))))
print("-- M1: g tan - f v + c*max(0, V - v), grid over V (and f)")
best = []
for f in (0.1875, 0.3, 0.4):
    for V in range(450, 1301, 50):
        M = np.c_[np.maximum(0, V - v)]
        c = np.linalg.lstsq(M, y - (g - f * v), rcond=None)[0][0]
        pred = g - f * v + c * np.maximum(0, V - v)
        best.append((np.sqrt(np.mean((y - pred) ** 2)), f, V, c))
for b in sorted(best)[:6]:
    f, V, c = b[1:]; rep("f %.3f V %d c %.3f" % (f, V, c), g - f * v + c * np.maximum(0, V - v))

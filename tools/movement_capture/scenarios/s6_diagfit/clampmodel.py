"""Air-jump add models vs measured (camera pre/post angles from ajadd.py, HUD h).
Model family: c = per-WORLD-axis clamp to [-1,1] of the unnormalized key vector (fwd*f + left*s) rotated by view yaw."""
import math, numpy as np
R = 386.0; A = 200.0
# name, yaw, keys(f,s), pre(f,l) mean, measured post angle, measured add angle, HUD h post (mean), camera |post|
cases = [
 ("DRD",  147.69, (0,-1), (0.3,-59.5), -89.99, -90.07, 265.4, 281.7),
 ("DRA",   57.75, (0, 1), (-0.1,54.7), 89.97, 89.94, 263.8, 278.1),
 ("DRWA", 147.69, (1, 1), (42.8,42.9), 48.32, 49.21, 269.0, 281.3),
 ("DGRWD",147.66, (1,-1), (41.9,-41.8), -41.73, -40.9, 272.0, 289.2),
 ("DGRSD",147.66, (-1,-1), (-44.4,-44.6), -131.75, -130.87, 273.6, 288.7),
 ("DRWDY",102.66, (1,-1), (43.1,-42.7), -48.64, -49.54, 314.2, 326.5),
 ("DRSA",  12.81, (-1, 1), (-43.0,42.9), 131.35, 130.5, 311.7, 327.3),
 ("DWA",  147.69, (1, 1), (332.8,0.2), 15.70, 47.9, 448.0, 463.3),
 ("DGWD", 147.66, (1,-1), (333.7,0.0), -10.38, -40.4, 422.8, 432.2),
 ("DGBSD",147.66, (-1,-1), (-339.4,0.0), -164.34, -128.8, 447.8, 455.3),
 ("DGBSA",147.66, (-1, 1), (-342.7,0.0), 169.55, 138.1, 425.6, 438.8),
 ("DBSA",  12.81, (-1, 1), (-171.4,-0.1), 149.89, 129.5, 371.1, 379.9),
 ("R1",   147.66, (-1,-1), (-297.3,0.0), -160.25, -128.4, 431.3, 441.8),
]
def rot(v, a):
    c, s = math.cos(a), math.sin(a); return np.array([c*v[0]-s*v[1], s*v[0]+c*v[1]])
def cvec(yaw, k, clamp=True):
    y = math.radians(yaw); w = rot(np.array(k, float), y)
    if clamp: w = np.clip(w, -1, 1)
    return rot(w, -y)
def model(name, yaw, k, pre, mode):
    v = np.array(pre, float)
    c = cvec(yaw, k, mode != "sim")
    if mode == "sim": c = c/np.linalg.norm(c)
    L = np.linalg.norm(c); d = c/L; al = v@d
    if mode in ("sim", "M0"):      add = min(A, R-al)          # dir clamped, size as now
    elif mode == "M1": add = min(A*L, R*L-al)                   # target and cap scale with |c|
    elif mode == "M2": add = min(A*L, R-al)                     # cap scales, target run
    elif mode == "M3": add = min(A, R*L-al)
    add = max(add, 0.0)
    return v + d*add
ang = lambda v: math.degrees(math.atan2(v[1], v[0]))
print("%-6s %6s %7s | %s" % ("case", "HUDh", "angP", "  ".join("%-16s" % m for m in ("sim", "M0", "M1", "M2", "M3"))))
err = {m: [] for m in ("sim", "M0", "M1", "M2", "M3")}
for cs in cases:
    n, yaw, k, pre, pa, aa, hh, cp = cs
    out = []
    for m in err:
        p = model(n, yaw, k, pre, m); out.append("%5.1f %7.2f   " % (np.linalg.norm(p), ang(p)))
        err[m].append((np.linalg.norm(p) - hh, (ang(p) - pa + 180) % 360 - 180))
    print("%-6s %6.1f %7.2f | %s" % (n, hh, pa, "".join(out)))
for m, e in err.items():
    e = np.array(e); print(m, "h err", np.round(e[:,0],1), "rms %.1f" % np.sqrt((e[:,0]**2).mean()), " ang err", np.round(e[:,1],2), "rms %.2f" % np.sqrt((e[:,1]**2).mean()))

print("\n--- per-axis and pre-scale variants (h err vs HUD, ang err vs camera post) ---")
def m_axis(yaw, k, pre, tgt_norm):
    y = math.radians(yaw); v = rot(np.array(pre, float), y)
    c = np.clip(rot(np.array(k, float), y), -1, 1)
    t = R * (c/np.linalg.norm(c) if tgt_norm else c)
    out = v.copy()
    for i in range(2):
        if abs(c[i]) < 1e-9: continue
        sg = math.copysign(1, c[i]); gap = sg*t[i] - sg*v[i]
        if gap > 0: out[i] += sg*min(A*abs(c[i]), gap)
    return rot(out, -y)
def m2(yaw, k, pre):
    return model("", yaw, k, pre, "M2")
for lab, f, sc in [("M2 pre*1", m2, 1.0), ("M2 pre/1.04", m2, 1/1.04), ("axis tgt c", lambda y,k,p: m_axis(y,k,p,False), 1.0),
                   ("axis tgt c^", lambda y,k,p: m_axis(y,k,p,True), 1.0), ("axis tgt c /1.04", lambda y,k,p: m_axis(y,k,p,False), 1/1.04)]:
    e = []
    for n, yaw, k, pre, pa, aa, hh, cp in cases:
        p = f(yaw, k, tuple(np.array(pre)*sc)); e.append((np.linalg.norm(p)-hh, (ang(p)-pa+180)%360-180))
    e = np.array(e); print("%-18s h" % lab, np.round(e[:,0],1), "rms %.1f" % np.sqrt((e[:,0]**2).mean()), "| ang", np.round(e[:,1],2), "rms %.2f" % np.sqrt((e[:,1]**2).mean()))

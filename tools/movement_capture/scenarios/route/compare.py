"""Game vs sim along a route. Usage: compare.py NAME YAW [STEP]  (reads rec_auto/route/NAME/*.csv and
scenarios/route/NAME_sim.csv). Game positions are the camera (fixed yaw and pitch, so displacement = hero
displacement, except crouch lowers the camera). Game tick = t*64+1, shifted so the first dash rises together."""
import sys, os, csv, glob, math, numpy as np
name, yaw = sys.argv[1], math.radians(float(sys.argv[2])); step = int(sys.argv[3]) if len(sys.argv) > 3 else 10
H = os.path.dirname(os.path.abspath(__file__))
sim = list(csv.DictReader(open(os.path.join(H, name + "_sim.csv"))))
st = np.array([int(r["tick"]) for r in sim]); sv = np.array([float(r["speed3d"]) for r in sim])
sf, sl, sz = (np.array([float(r[k]) for r in sim]) for k in ("fwd", "left", "up"))
fx, fy = math.cos(yaw), math.sin(yaw)
def first_over(t, v, x=600): return t[np.argmax(v > x)]
games = []
for p in sorted(glob.glob(os.path.join(H, "..", "..", "rec_auto", "route", name, "*.csv"))):
    r = [x for x in csv.DictReader(open(p)) if x.get("valid", "1") == "1" and x["vel_scalar"] and x["pos_x"]]
    t = np.array([float(x["t"]) for x in r]) * 64 + 1
    P = np.array([[float(x["pos_x"]), float(x["pos_y"]), float(x["pos_z"])] for x in r]); P -= P[0]
    v = np.array([float(x["vel_scalar"]) for x in r])
    t = t + (first_over(st, sv) - first_over(t, v))
    f = P[:, 0] * fx + P[:, 1] * fy; l = -P[:, 0] * fy + P[:, 1] * fx
    games.append((t, v, f, l, P[:, 2]))
print("tick  loco        | speed sim  game...      | fwd sim  game...        | left sim  game...    | up sim  game...")
for k in range(0, int(st[-1]) + 1, step):
    g = [tuple(np.interp(k, t, a) for a in (v, f, l, z)) for t, v, f, l, z in games if t[0] <= k <= t[-1]]
    if not g: continue
    j = int(np.searchsorted(st, k))
    print("%4d  %-11s | %5.0f %s | %6.0f %s | %5.0f %s | %4.0f %s" % (k, sim[j]["loco"][:11], sv[j], " ".join("%5.0f" % x[0] for x in g),
          sf[j], " ".join("%6.0f" % x[1] for x in g), sl[j], " ".join("%5.0f" % x[2] for x in g), sz[j], " ".join("%4.0f" % x[3] for x in g)))

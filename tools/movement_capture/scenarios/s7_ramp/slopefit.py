"""Ramp profile from RWALK (run from tools/movement_capture): camera z vs hero distance along the mark facing,
fitted with flat / linear slope / flat (d0, d1, drop). Prints the slope angle and the start/end in world coords."""
import sys, os, glob, math, json
import numpy as np
sys.path.insert(0, os.path.dirname(__file__)); os.environ["MARK"] = "ramp1_top"
import ana
mark = json.load(open("driver/marks.json"))["ramp1_top"]
D, Z = [], []
for p in sorted(glob.glob("rec_auto/s7_ramp/RWALK/*.csv")):
    t, d, lat, z, sp = ana.load(p); k = t < 3.0; D += list(d[k]); Z += list(z[k])
D, Z = np.array(D), np.array(Z)
def model(d, d0, d1, H): return np.where(d < d0, 0, np.where(d > d1, -H, -H * (d - d0) / (d1 - d0)))
best = None
for d0 in np.arange(80, 180, 1.0):
    for d1 in np.arange(330, 480, 1.0):
        H = -np.median(Z[D > 480]); r = np.sum((Z - model(D, d0, d1, H)) ** 2)
        if best is None or r < best[0]: best = (r, d0, d1, H)
r, d0, d1, H = best; L = d1 - d0
print("slope from d=%.0f to d=%.0f u (along yaw %.1f from ramp1_top pawn), horizontal %.0f u, drop %.1f u, angle %.1f deg (rms %.2f u)"
      % (d0, d1, mark["yaw"], L, H, math.degrees(math.atan2(H, L)), math.sqrt(r / len(D))))
c, s = math.cos(math.radians(mark["yaw"])), math.sin(math.radians(mark["yaw"])); P = mark["pawn"]
for nm, dd, zz in (("top edge", d0, P[2]), ("bottom edge", d1, P[2] - H)):
    print("  %s ~ (%.0f, %.0f, %.0f)" % (nm, P[0] + c * dd, P[1] + s * dd, zz))
k = (D > d0 + 60) & (D < d1 - 60); g = np.polyfit(D[k], Z[k], 1)
print("mid-slope linear fit: dz/dd = %.4f -> %.1f deg along the facing (fall line may be ~8 deg off the facing)" % (g[0], math.degrees(math.atan(-g[0]))))

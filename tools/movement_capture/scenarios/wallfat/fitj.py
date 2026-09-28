"""Fixed-gravity (800 u/s^2) fits of camera z and a linear fit of forward position, before and after each press.
Windows: [P-W, P-1] and [P+2, P+W+2] ticks. Prints vz and fwd extrapolated to the press tick.
Usage: fitj.py YAW W CSV P [P...]"""
import csv, sys, math
import numpy as np
yaw = math.radians(float(sys.argv[1])); W = float(sys.argv[2]); fx, fy = math.cos(yaw), math.sin(yaw)
R = [r for r in csv.DictReader(open(sys.argv[3])) if r["valid"] == "1" and r["pos_x"]]
T = np.array([float(r["t"]) * 64 + 1 for r in R]); Z = np.array([float(r["pos_z"]) for r in R])
F = np.array([float(r["pos_x"]) * fx + float(r["pos_y"]) * fy for r in R])
def fit(a, b, P):
    m = (T >= a) & (T <= b)
    if m.sum() < 4: return float("nan"), float("nan")
    t = (T[m] - P) / 64
    vz = np.polyfit(t, Z[m] + 400 * t * t, 1)[0]
    vf = np.polyfit(t, F[m], 1)[0]
    return vz, vf
out = []
for P in map(float, sys.argv[4:]):
    zb, fb = fit(P - W, P - 1, P); za, fa = fit(P + 2, P + 2 + W, P)
    out.append("P%3.0f vz %5.0f -> %5.0f  fwd %5.0f -> %5.0f" % (P, zb, za, fb, fa))
print("%-40s %s" % (sys.argv[3], "   ".join(out)))

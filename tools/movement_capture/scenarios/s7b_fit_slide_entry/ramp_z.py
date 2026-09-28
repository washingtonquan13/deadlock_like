"""s7b: where is the hero when ramp1 RRUN/RJ crouch acts? Camera z (aligned 4-tick lag) of RRUN/RJ minus the SE336 mean
(same inputs on flat: same crouch camera drop), per tick, plus the displacement along the path (u) from the start.
Usage: python scenarios/s7b_fit_slide_entry/ramp_z.py"""
import csv, glob
import numpy as np
L = 4.0
def g(p):
    R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1" and r["pos_z"] and r["vel_scalar"]]
    k = np.array([float(r["t"]) * 64 + 1 - L for r in R])
    x = np.array([float(r["pos_x"]) for r in R]); y = np.array([float(r["pos_y"]) for r in R]); z = np.array([float(r["pos_z"]) for r in R])
    i0 = np.argmin(abs(k - 1))
    d = np.hypot(x - x[i0], y - y[i0])
    return k, z - z[i0], d, np.array([float(r["vel_scalar"]) for r in R])
ks = np.arange(26, 46, 1)
ref = np.mean([np.interp(ks, *g(p)[:2]) for p in glob.glob("rec_auto/s7_open/SE336/ts1_t*.csv")], axis=0)
print("tick           " + " ".join("%5d" % k for k in ks))
print("SE336 z        " + " ".join("%5.1f" % x for x in ref))
for p in sorted(glob.glob("rec_auto/s7_ramp/RRUN/*ts1_t*.csv") + glob.glob("rec_auto/s7_ramp/RJ/ts1_t*.csv")):
    k, z, d, v = g(p)
    nm = "/".join(p.replace("\\", "/").split("/")[-2:])[:-4]
    print("%-14s " % nm[-14:] + " ".join("%5.1f" % x for x in np.interp(ks, k, z) - ref))
    print("   disp u      " + " ".join("%5.0f" % x for x in np.interp(ks, k, d)))

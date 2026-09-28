"""s7b: ramp1 RRUN/RJ crouch at tick 33 (W 1..32) vs flat SE336 (same inputs). Game HUD aligned with the 4-tick lag;
prints the aligned speed at ticks 30..44 and z (camera) so the slope start is visible, plus sim (s7_ramp cur_*).
Usage: python scenarios/s7b_fit_slide_entry/ramp_check.py"""
import csv, glob
import numpy as np
L = 4.0
def g(p):
    R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1" and r["vel_scalar"] and r["pos_z"]]
    k = np.array([float(r["t"]) * 64 + 1 - L for r in R])
    return k, np.array([float(r["vel_scalar"]) for r in R]), np.array([float(r["pos_z"]) for r in R])
ks = np.arange(28, 50, 2)
print("tick      " + " ".join("%6d" % k for k in ks))
for n, pat in (("SE336", "s7_open/SE336/ts1_t*.csv"), ("RRUN", "s7_ramp/RRUN/*ts1_t*.csv"), ("RJ", "s7_ramp/RJ/ts1_t*.csv")):
    for p in sorted(glob.glob("rec_auto/" + pat)):
        k, v, z = g(p)
        print("%-5s %-7s" % (n, p.replace("\\", "/").split("/")[-1][:-4][-8:]) + " ".join("%6.1f" % np.interp(x, k, v) for x in ks)
              + "  | dz(t32->44) %.1f" % (np.interp(44, k, z) - np.interp(32, k, z)))
for n in ("RRUN", "RJ"):
    S = list(csv.DictReader(open("../../tools_fit/_out/s7_ramp/cur_%s.csv" % n)))
    print("sim %-4s    " % n + " ".join("%6.1f" % float(S[x]["speed_h"]) for x in ks) + "  " + " ".join(S[x]["loco"][:2] for x in ks) + " up@44 %.1f" % float(S[44]["up"]))

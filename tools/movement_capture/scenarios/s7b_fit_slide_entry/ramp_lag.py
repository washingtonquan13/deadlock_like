"""s7b: per-trial lag fit (HUD 60..330 of the W ramp-up vs the sim SEPROBE curve) for RRUN/RJ and SE336/SE340, then the
game speed at the last W tick (32 for RRUN/RJ/SE336, 33 for SE340) in sim-aligned time, and the first aligned tick
where the trace departs from crouch-walk (slide) or not. Usage: python scenarios/s7b_fit_slide_entry/ramp_lag.py"""
import csv, glob
import numpy as np
S = list(csv.DictReader(open("../../tools_fit/_out/s7b_slide_entry/cur_SEPROBE.csv")))
st = np.array([float(r["tick"]) for r in S]); sv = np.array([float(r["speed_h"]) for r in S])
lags = np.arange(1, 7.01, 0.125)
for n, pat, last in (("SE336", "s7_open/SE336/ts1_t*.csv", 32), ("SE340", "s7_open/SE340/ts1_t*.csv", 33),
                     ("RRUN", "s7_ramp/RRUN/*ts1_t*.csv", 32), ("RJ", "s7_ramp/RJ/ts1_t*.csv", 32)):
    for p in sorted(glob.glob("rec_auto/" + pat)):
        R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1" and r["vel_scalar"]]
        k0 = np.array([float(r["t"]) * 64 + 1 for r in R]); v = np.array([float(r["vel_scalar"]) for r in R])
        m = (v > 60) & (v < 330) & (k0 < last)
        err = [np.sqrt(np.mean((v[m] - np.interp(k0[m] - L, st, sv)) ** 2)) for L in lags]
        L = lags[int(np.argmin(err))]
        k = k0 - L
        print("%-5s %-9s lag %.2f rms %.1f | v[last=%d] %.1f v[last+2] %.1f v[last+5] %.1f" % (
            n, p.replace("\\", "/").split("/")[-1][:-4], L, min(err), last, np.interp(last, k, v), np.interp(last + 2, k, v), np.interp(last + 5, k, v)))

"""cmp.py NAME [simcsv] [t0 t1]: per-tick game HUD (each trial, interpolated to integer ticks) vs sim speed3d."""
import sys, glob, csv, os, numpy as np
MC = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROOT = os.path.abspath(os.path.join(MC, "..", ".."))
n = sys.argv[1]
simf = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else os.path.join(ROOT, "tools_fit", "_out", "s6_%s.csv" % n)
t0, t1 = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (0, 150)
tr = []
for f in sorted(glob.glob(os.path.join(MC, "rec_auto", "s6_airdash", n, "*.csv"))):
    r = [x for x in csv.DictReader(open(f)) if x["valid"] == "1" and x["vel_scalar"]]
    t = np.array([float(x["t"]) * 64 + 1 for x in r]); h = np.array([float(x["vel_scalar"]) for x in r])
    z = np.array([float(x["pos_z"] or "nan") for x in r])
    tr.append((t, h, z))
s = list(csv.DictReader(open(simf)))
print("tick  " + "  ".join("g%d   " % i for i in range(len(tr))) + " sim3d  simh  loco")
for k in range(t0, t1):
    g = []
    for t, h, z in tr:
        g.append(np.interp(k, t, h) if t.min() <= k <= t.max() else float("nan"))
    sr = s[k] if k < len(s) else None
    print("%4d " % k + " ".join("%6.1f" % v for v in g) + "  %6s %6s %s" % ((sr["speed3d"], sr["speed_h"], sr["loco"]) if sr else ("", "", "")))

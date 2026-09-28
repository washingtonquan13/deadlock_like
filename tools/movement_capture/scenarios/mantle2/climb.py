"""Per-trial climb summary for any ledge: plateau = longest run of steady HUD speed (>150, step < 0.6) while z rises.
Prints the plateau speed, its ticks, z (relative to the first sample) at its start and end, the exit plateau, the top."""
import sys, os, glob, csv, numpy as np
f = lambda v: float(v) if v not in ("", None) else float("nan")
def runs(mask):
    out, cur = [], None
    for i, v in enumerate(list(mask) + [False]):
        if v and cur is None: cur = i
        if not v and cur is not None: out.append((cur, i - 1)); cur = None
    return out
for d in sys.argv[1:]:
    for p in sorted(glob.glob(os.path.join(d, "*.csv"))):
        r = [x for x in csv.DictReader(open(p)) if x["valid"] == "1" and x["pos_z"] and x["vel_scalar"]]
        t = np.array([f(x["t"]) for x in r]) * 64 + 1; sp = np.array([f(x["vel_scalar"]) for x in r]); z = np.array([f(x["pos_z"]) for x in r]); z -= z[0]
        steady = np.r_[False, np.abs(np.diff(sp)) < 0.6] & (sp > 150)
        rr = sorted(runs(steady), key=lambda ab: t[ab[1]] - t[ab[0]], reverse=True)
        climb = next((ab for ab in rr if z[ab[1]] - z[ab[0]] > 10), None)
        s = "%-22s zmax %5.1f zend %5.1f" % (os.path.relpath(p, "rec_auto"), np.nanmax(z), z[-1])
        if climb:
            a, b = climb
            s += " | climb %5.1f u/s ticks %5.1f-%5.1f z %5.1f->%5.1f" % (np.median(sp[a:b + 1]), t[a], t[b], z[a], z[b])
            ex = next((ab for ab in runs(steady) if t[ab[0]] > t[b] and t[ab[1]] - t[ab[0]] > 3), None)
            if ex: s += " | exit %5.1f ticks %5.1f-%5.1f" % (np.median(sp[ex[0]:ex[1] + 1]), t[ex[0]], t[ex[1]])
        else:
            s += " | no climb"
        print(s)

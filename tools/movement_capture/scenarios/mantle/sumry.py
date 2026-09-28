"""Per-trial mantle summary: the longest run with HUD speed ~215.6 (the climb), the speed after it, top reached."""
import sys, os, glob, csv, numpy as np
f = lambda v: float(v) if v not in ("", None) else float("nan")
for d in sys.argv[1:]:
    for p in sorted(glob.glob(os.path.join(d, "*.csv"))):
        r = [x for x in csv.DictReader(open(p)) if x["valid"] == "1"]
        t = np.array([f(x["t"]) for x in r]); sp = np.array([f(x["vel_scalar"]) for x in r]); z = np.array([f(x["pos_z"]) for x in r])
        s = "%-24s ztop %5.1f zend %5.1f" % (os.path.relpath(p, "rec_auto/mantle"), np.nanmax(z) - z[0], z[-1] - z[0])
        best, cur = (0, 0), None
        for i, v in enumerate(np.abs(sp - 215.6) < 2.0):
            if v and cur is None: cur = i
            if (not v or i == len(sp) - 1) and cur is not None:
                j = i if v else i - 1
                if t[j] - t[cur] > t[best[1]] - t[best[0]]: best = (cur, j)
                cur = None
        if t[best[1]] - t[best[0]] > 0.05:
            a, b = best
            k0 = max(0, a - 12)
            s += "  climb %.3f-%.3f (%.3f s) z %.1f->%.1f  exit %s" % (t[a], t[b], t[b] - t[a], z[a] - z[0], z[b] - z[0], np.round(sp[b + 1:b + 5], 1))
        print(s)

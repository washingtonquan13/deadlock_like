"""hopfit variant: SHH6 second flight, window ends CUT ticks before landing, vz0 = G*T/2 + DV."""
import sys, numpy as np
from hopfit import flight, integ, G, D0, trials
CUT, DV = float(sys.argv[1]), float(sys.argv[2])
data = []
for p in trials("s6_slidejump", "SHH6"):
    t0, t1, hg, s, sp = flight(p, 82, 120)
    m = s < (t1 - t0 - CUT) / 64
    data.append((t0, t1, hg, s[m], sp[m]))
def run(f, grid):
    best = None
    for prm in grid:
        r2 = n = 0
        for t0, t1, hg, s, sp in data:
            vz0 = G * (t1 - t0) / 128 + DV
            e = np.sqrt(f(prm, hg, s) ** 2 + (vz0 - G * s) ** 2) - sp
            r2 += np.sum(e ** 2); n += len(e)
        r = np.sqrt(r2 / n)
        if best is None or r < best[0]: best = (r, prm)
    r, p = best
    T = (data[0][1] - data[0][0]) / 64
    hs = f(p, data[0][2], np.array([0.0, 8 / 64, 16 / 64, 22 / 64, T]))
    return r, p, hs
M = {
 "cut c then 0.2": (lambda p, hg, s: integ(hg * p, s, lambda t, h: D0 * h), np.arange(0.55, 1.0, 0.005)),
 "0.2+P whole": (lambda p, hg, s: integ(hg, s, lambda t, h: (D0 + p) * h), np.arange(0, 3, 0.02)),
 "0.2+P for N ticks": (lambda p, hg, s: integ(hg, s, lambda t, h: (D0 + (p[0] if t * 64 < p[1] else 0)) * h),
                       [(a, b) for a in np.arange(0.4, 4, 0.05) for b in range(4, 45)]),
 "cut c + 0.2+P for N": (lambda p, hg, s: integ(hg * p[2], s, lambda t, h: (D0 + (p[0] if t * 64 < p[1] else 0)) * h),
                       [(a, b, c) for a in np.arange(0.4, 3, 0.1) for b in range(4, 45, 2) for c in np.arange(0.9, 1.001, 0.02)]),
 "0.2+P*exp(-t/tau)": (lambda p, hg, s: integ(hg, s, lambda t, h: (D0 + p[0] * np.exp(-t / p[1])) * h),
                       [(a, b) for a in np.arange(0.5, 5, 0.1) for b in np.arange(0.05, 1.0, 0.025)]),
 "0.2+k*(h-ht)+": (lambda p, hg, s: integ(hg, s, lambda t, h: D0 * h + p[0] * max(h - p[1], 0)),
                   [(a, b) for a in np.arange(0.5, 8, 0.1) for b in range(100, 300, 5)]),
}
for k, (f, g) in M.items():
    r, p, hs = run(f, g)
    print("CUT %g DV %+g  %-22s rms %5.2f %-40s h@0/8/16/22/land %s" % (CUT, DV, k, r, str(np.round(p, 3).tolist() if p is not None else p), np.round(hs).astype(int).tolist()))

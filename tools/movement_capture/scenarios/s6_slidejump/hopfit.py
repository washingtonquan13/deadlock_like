"""G09 chained slide hop: fit the second flight of SHH6 (and SHH40 control) with pinned vz0 = G*T/2.
Models for horizontal speed h(s), s = seconds after takeoff; h0 = ground HUD just before takeoff (no cut on a
landing-slide jump, NSJ48/SHH40), unless the model frees it.
Usage: hopfit.py"""
import sys, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from load import load, trials
G, D0 = 796.0, 0.2

def flight(path, tmin, tland_min):
    tk, sp, _ = load(path)
    i0 = [i for i in range(1, len(tk)) if tk[i] > tmin and sp[i] > sp[i - 1] + 5][0]
    i1 = [i for i in range(1, len(tk)) if tk[i] > tland_min and sp[i] < sp[i - 1] - 6][0]
    t0 = (tk[i0 - 1] + tk[i0]) / 2; t1 = (tk[i1 - 1] + tk[i1]) / 2
    hg = np.median(sp[(tk > t0 - 4) & (tk < t0 - 0.6)])
    m = (tk > t0 + 0.6) & (tk < t1 - 0.6)
    return t0, t1, hg, (tk[m] - t0) / 64, sp[m]

def hud(hs, s, T):
    vz0 = G * T / 64 / 2
    return np.sqrt(hs ** 2 + (vz0 - G * s) ** 2)

def integ(h0, s, dfun):
    # h' = -D(t) h (+ extra), integrated by 1/64 steps
    out = []; h = h0; t = 0.0; dt = 1 / 64; ss = np.sort(s); j = 0; res = {}
    tmax = s.max() + dt
    while t <= tmax:
        res[round(t * 64)] = h
        h = h - dfun(t, h) * dt
        t += dt
    return np.array([np.interp(x * 64, list(res.keys()), list(res.values())) for x in s])

def fit(name, data, model, grid):
    best = None
    for prm in grid:
        r2 = 0; n = 0
        for t0, t1, hg, s, sp in data:
            hs = model(prm, hg, s)
            e = hud(hs, s, t1 - t0) - sp
            r2 += np.sum(e ** 2); n += len(e)
        r = np.sqrt(r2 / n)
        if best is None or r < best[0]: best = (r, prm)
    return best

models = {
    "0.2 only (no penalty)": (lambda p, hg, s: integ(hg, s, lambda t, h: D0 * h), [None]),
    "cut c, then 0.2": (lambda p, hg, s: integ(hg * p, s, lambda t, h: D0 * h), [c for c in np.arange(0.55, 1.0, 0.005)]),
    "0.2+P whole flight": (lambda p, hg, s: integ(hg, s, lambda t, h: (D0 + p) * h), [x for x in np.arange(0, 3, 0.02)]),
    "0.2+P for N ticks": (lambda p, hg, s: integ(hg, s, lambda t, h: (D0 + (p[0] if t * 64 < p[1] else 0)) * h),
                          [(a, b) for a in np.arange(0.4, 4, 0.05) for b in range(4, 45, 1)]),
    "0.2+P*exp(-t/tau)": (lambda p, hg, s: integ(hg, s, lambda t, h: (D0 + p[0] * np.exp(-t / p[1])) * h),
                          [(a, b) for a in np.arange(0.5, 5, 0.1) for b in np.arange(0.05, 1.0, 0.025)]),
    "0.2 + k*(h-ht)+": (lambda p, hg, s: integ(hg, s, lambda t, h: D0 * h + p[0] * max(h - p[1], 0)),
                        [(a, b) for a in np.arange(0.5, 8, 0.1) for b in range(100, 300, 5)]),
}
if __name__ == "__main__":
    for nm, tmin, tl in [("SHH6", 82, 120), ("SHH40", 116, 155)]:
        data = [flight(p, tmin, tl) for p in trials("s6_slidejump", nm)]
        for t0, t1, hg, s, sp in data:
            print("%s takeoff %.1f land %.1f T %.1f vz0 %.0f h_ground %.1f" % (nm, t0, t1, t1 - t0, G * (t1 - t0) / 128, hg))
        for k, (f, grid) in models.items():
            r, p = fit(nm, data, f, grid)
            hs = f(p, data[0][2], np.array([0.0, 22 / 64, (data[0][1] - data[0][0]) / 64]))
            print("  %-24s rms %5.2f  params %s  h: takeoff %.0f apex %.0f land %.0f" % (k, r, p, *hs))

"""G09 chained slide-hop penalty across hop speeds: SHH6/12/20/30 (~370-380 u/s, s6/s7) and SHL6/SHL12 (~470 u/s, s9).
Second flight: takeoff/landing from HUD jumps, vz0 and G from a parabola fit to z (SHL lands on a curb, so T is not
a flat flight), h0 = ground HUD before takeoff. Horizontal h(s) models are fitted jointly and per scenario.
Usage: g09fit.py"""
import sys, os, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "s6_slidejump"))
from hopfit import integ, D0, G
from load import load, trials
SETS = [("s6_slidejump", "SHH6", 82, 120), ("s7_open", "SHH12", 86, 124), ("s7_open", "SHH20", 94, 130),
        ("s7_open", "SHH30", 104, 140), ("s9_open", "SHL6", 157, 195), ("s9_open", "SHL12", 163, 200)]
def flight(path, tmin, tland_min):
    tk, sp, pos = load(path)
    i0 = [i for i in range(1, len(tk)) if tk[i] > tmin and sp[i] > sp[i - 1] + 5][0]
    i1 = [i for i in range(1, len(tk)) if tk[i] > tland_min and sp[i] < sp[i - 1] - 6][0]
    t0 = (tk[i0 - 1] + tk[i0]) / 2; t1 = (tk[i1 - 1] + tk[i1]) / 2
    hg = np.median(sp[(tk > t0 - 4) & (tk < t0 - 0.6)])
    m = (tk > t0 + 0.6) & (tk < t1 - 0.6)
    s = (tk[m] - t0) / 64
    # lateral drift off the start line (SHL6 hits something near the apex): keep frames before it
    xy = pos[m, :2]; d = xy - xy[0]; u = d[-1] / (np.linalg.norm(d[-1]) + 1e-9)
    b, a = np.polyfit(s, pos[m, 2] + 0.5 * G * s ** 2, 1)   # z = a + vz0 s - G s^2 / 2, G pinned
    return dict(t0=t0, t1=t1, hg=hg, s=s, sp=sp[m], vz0=b, G=G)
def hud(hs, s, f):
    return np.sqrt(hs ** 2 + (f["vz0"] - f["G"] * s) ** 2)
D = {}
for st, nm, a, b in SETS:
    D[nm] = []
    for p in trials(st, nm):
        try: D[nm].append(flight(p, a, b))
        except IndexError: print("skip", p)
    for f in D[nm]:
        imin = np.argmin(f["sp"])
        print("%-6s takeoff %.1f land %.1f T %.1f h0 %.1f vz0 %.0f G %.0f HUDmin %.1f @+%.1f" % (
            nm, f["t0"], f["t1"], f["t1"] - f["t0"], f["hg"], f["vz0"], f["G"], f["sp"][imin], f["s"][imin] * 64))
def fit(data, fn, grid, smax=None):
    best = None
    for prm in grid:
        r2 = n = 0
        for f in data:
            k = f["s"] < (smax or 9)
            e = hud(fn(prm, f["hg"], f["s"][k]), f["s"][k], f) - f["sp"][k]; r2 += np.sum(e ** 2); n += len(e)
        r = np.sqrt(r2 / max(n, 1))
        if best is None or r < best[0]: best = (r, prm)
    return best
box = lambda p, hg, s: integ(hg, s, lambda t, h: (D0 + (p[0] if t * 64 < p[1] else 0)) * h)
M = {"none": (lambda p, hg, s: integ(hg, s, lambda t, h: D0 * h), [None]),
     "box 1.34,20 (sim now)": (box, [(1.34, 20)]),
     "box P,N": (box, [(a, b) for a in np.arange(0.5, 4.0, 0.05) for b in range(8, 41, 1)]),
     "target k,ht: -k(h-ht)+": (lambda p, hg, s: integ(hg, s, lambda t, h: D0 * h + p[0] * max(h - p[1], 0)),
                                [(a, b) for a in np.arange(0.5, 10, 0.25) for b in range(100, 320, 5)]),
     "decel a for N ticks": (lambda p, hg, s: integ(hg, s, lambda t, h: D0 * h + (p[0] if t * 64 < p[1] else 0)),
                             [(a, b) for a in range(100, 1400, 25) for b in range(8, 41, 1)]),
     "target box k,ht,N": (lambda p, hg, s: integ(hg, s, lambda t, h: D0 * h + (p[0] * max(h - p[1], 0) if t * 64 < p[2] else 0)),
                           [(a, b, c) for a in np.arange(1, 10, 0.5) for b in range(100, 320, 10) for c in (16, 20, 24, 28, 32, 40, 64)])}
SMAX = float(os.environ.get("SMAX", "0.5"))  # fit window after takeoff (s): SHL6 drifts sideways from ~0.45 s
pen = [n for n in D if D[n]]
for k, (fn, g) in M.items():
    print("== model", k)
    r, p = fit([x for n in pen for x in D[n]], fn, g, SMAX)
    print("  joint: rms %.2f params %s" % (r, None if p is None else np.round(p, 3).tolist()))
    for n in pen:
        rr, pp = fit(D[n], fn, g, SMAX); rj = fit(D[n], fn, [p], SMAX)[0]
        f = D[n][0]; hs = fn(p, f["hg"], np.array([0.0, 0.15, 0.3, 0.45]))
        print("  %-6s own rms %5.2f params %-20s | joint rms %6.2f  h: 0 %.0f .15s %.0f .3s %.0f .45s %.0f" % (
            n, rr, None if pp is None else np.round(pp, 3).tolist(), rj, *hs))

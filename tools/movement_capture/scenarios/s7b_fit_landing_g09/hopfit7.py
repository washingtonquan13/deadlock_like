"""G09 chained slide-hop penalty at hop delays 6/12/20/30 ticks (SHH6 s6 set, SHH12/20/30 s7_open) + SHH40 control.
Second flight: takeoff t0 / landing t1 from HUD jumps, vz0 = G*T/2 pinned, h0 = ground HUD before takeoff.
Fits the extra air drag shapes jointly and per scenario; prints h at apex and landing.
Usage: hopfit7.py"""
import sys, os, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "s6_slidejump"))
from hopfit import flight, integ, hud, G, D0
from load import trials
VZ0 = float(os.environ.get("VZ0", "0"))  # >0: pin vz0 to this (SHH30/SHH40 level flights give ~292); 0: G*T/2
if VZ0 > 0:
    hud = lambda hs, s, T: np.sqrt(hs ** 2 + (VZ0 - G * s) ** 2)
SETS = [("s6_slidejump", "SHH6", 82, 120), ("s7_open", "SHH12", 86, 124), ("s7_open", "SHH20", 94, 130),
        ("s7_open", "SHH30", 104, 140), ("s6_slidejump", "SHH40", 116, 155)]
D = {}
for st, nm, a, b in SETS:
    D[nm] = [flight(p, a, b) for p in trials(st, nm)]
    for t0, t1, hg, s, sp in D[nm]:
        imin = np.argmin(sp)
        print("%-6s takeoff %.1f land %.1f T %.1f  h_ground %.1f  HUDmin %.1f @+%.1f  last-air HUD %.1f" % (
            nm, t0, t1, t1 - t0, hg, sp[imin], s[imin] * 64, sp[-1]))
def fit(data, f, grid):
    best = None
    for prm in grid:
        r2 = n = 0
        for t0, t1, hg, s, sp in data:
            e = hud(f(prm, hg, s), s, t1 - t0) - sp; r2 += np.sum(e ** 2); n += len(e)
        r = np.sqrt(r2 / n)
        if best is None or r < best[0]: best = (r, prm)
    return best
box = lambda p, hg, s: integ(hg, s, lambda t, h: (D0 + (p[0] if t * 64 < p[1] else 0)) * h)
M = {"none": (lambda p, hg, s: integ(hg, s, lambda t, h: D0 * h), [None]),
     "box P,N": (box, [(a, b) for a in np.arange(0.5, 3.0, 0.05) for b in range(8, 41, 1)]),
     "box 1.3,20 (sim now)": (box, [(1.3, 20)]),
     "exp P,tau": (lambda p, hg, s: integ(hg, s, lambda t, h: (D0 + p[0] * np.exp(-t / p[1])) * h),
                   [(a, b) for a in np.arange(0.5, 5, 0.1) for b in np.arange(0.05, 1.0, 0.025)])}
pen = ["SHH6", "SHH12", "SHH20", "SHH30"]
for k, (f, g) in M.items():
    print("== model", k)
    r, p = fit([x for n in pen for x in D[n]], f, g)
    print("  joint SHH6/12/20/30: rms %.2f params %s" % (r, None if p is None else np.round(p, 3).tolist()))
    for n in pen + ["SHH40"]:
        rr, pp = fit(D[n], f, g)
        rj = fit(D[n], f, [p])[0]
        t0, t1, hg, s, sp = D[n][0]
        hs = f(p, hg, np.array([0.0, 0.3, (t1 - t0) / 64]))
        print("  %-6s own rms %5.2f params %-16s | joint-params rms %6.2f  h: 0 %.0f  +0.3s %.0f  land %.0f" % (
            n, rr, None if pp is None else np.round(pp, 3).tolist(), rj, *hs))

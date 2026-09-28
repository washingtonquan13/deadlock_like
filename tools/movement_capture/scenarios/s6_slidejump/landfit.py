"""Landing loss from the HUD alone: over the last ~14 ticks of the fall, HUD^2 = (h1 e^{D s})^2 + (vzl + G s)^2
(s = time before the landing t1, D = 0.2 fixed, vzl < 0 and h1 free; vzl is checked against the rise).
v_post = the ground HUD trend over t1+1.2..t1+7 extrapolated back to t1. ratio = v_post / h1.
Usage: landfit.py SET NAME MINTICK [...]  (MINTICK: search for the landing after this tick)."""
import sys, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from load import load, trials
D, G = 0.2, 796.0
def land(path, J):
    tk, sp, _ = load(path)
    i1 = None
    for i in range(3, len(tk)):
        if tk[i] < J: continue
        if sp[i] < sp[i - 1] - 6 and sp[i - 1] > sp[i - 3]:
            i1 = i; break
    if i1 is None: return None
    t1 = tk[i1 - 1] + 0.5 * (tk[i1] - tk[i1 - 1])
    m = (tk > t1 - 14) & (tk < t1 - 1.5); s = (t1 - tk[m]) / 64
    best = None
    for vzl in np.arange(-700, -100, 0.5):
        e = np.exp(2 * D * s); y = sp[m] ** 2 - (vzl + G * s) ** 2
        h2 = np.sum(y * e) / np.sum(e * e)
        if h2 <= 0: continue
        r = np.sqrt(np.mean((np.sqrt(h2 * e + (vzl + G * s) ** 2) - sp[m]) ** 2))
        if best is None or r < best[0]: best = (r, vzl, np.sqrt(h2))
    post = (tk > t1 + 1.2) & (tk < t1 + 7)
    c = np.polyfit(tk[post], sp[post], 1)
    return t1, best, np.polyval(c, t1), c[0]
if __name__ == "__main__":
    a = sys.argv[1:]
    for i in range(0, len(a), 3):
        st, nm, J = a[i], a[i + 1], float(a[i + 2])
        for p in trials(st, nm):
            r = land(p, J)
            if r is None: print(nm, "no landing"); continue
            t1, (rms, vzl, h1), vp, sl = r
            print("%-7s %s  land %6.1f  vz_land %5.0f  h_land %5.1f (rms %.1f)  post %5.1f (slope %5.2f/tick)  ratio %.3f  drop %5.1f" % (
                nm, p[-10:-4], t1, vzl, h1, rms, vp, sl, vp / h1, h1 - vp))

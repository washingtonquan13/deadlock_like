"""Slide-jump takeoff / landing from the HUD alone (session 6).
Model in the air (t from takeoff t0): h = h0*exp(-D*t), vz = vz0 - G*t, HUD = sqrt(h^2 + vz^2), D = 0.2/s, G = 796.
vz0 is PINNED from the airtime: vz0 = G*(t1 - t0)/2 with t1 the landing (first HUD drop after the apex) and t0 the
takeoff (grid-searched). h0 then comes from a closed-form LS on HUD^2 - vz^2 = h0^2 exp(-2 D t).
Also reported: h at the HUD minimum (apex cross-check, vz0-free), pre-jump ground speed extrapolated to t0,
and the first post-landing ground HUD vs the model h at landing.
Usage: fitsj.py SET NAME JUMPTICK [SET NAME JUMPTICK ...]  (only flat-ground takeoff/landing make sense)."""
import sys, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from load import load, trials
D, G = 0.2, 796.0
def fit_trial(path, J, D=D, G=G, verbose=False):
    tk, sp, pos = load(path)
    # landing: first sample, >=30 ticks after the press, where HUD falls >6 u/s vs the previous sample after having risen
    i1 = None
    for i in range(1, len(tk)):
        if tk[i] < J + 30: continue
        if sp[i] < sp[i - 1] - 6 and sp[i - 1] > sp[i - 3] :
            i1 = i; break
    if i1 is None: return None
    t1 = tk[i1 - 1] + 0.5 * (tk[i1] - tk[i1 - 1])   # landing transition (display time)
    best = None
    for t0 in np.arange(J - 1.0, J + 4.0, 0.02):
        vz0 = G * (t1 - t0) / 128.0
        m = (tk > t0 + 1.5) & (tk < t1 - 1.5)
        tau = (tk[m] - t0) / 64.0
        e = np.exp(-2 * D * tau); y = sp[m] ** 2 - (vz0 - G * tau) ** 2
        h02 = np.sum(y * e) / np.sum(e * e)
        if h02 <= 0: continue
        pred = np.sqrt(h02 * e + (vz0 - G * tau) ** 2)
        r = np.sqrt(np.mean((pred - sp[m]) ** 2))
        if best is None or r < best[0]: best = (r, t0, vz0, np.sqrt(h02))
    r, t0, vz0, h0 = best
    # free-vz0 check (D fixed): vary vz0 around the pinned one
    bf = None
    for t0b in np.arange(t0 - 1.5, t0 + 1.5, 0.05):
        for vzb in np.arange(vz0 - 30, vz0 + 30, 0.5):
            m = (tk > t0b + 1.5) & (tk < t1 - 1.5); tau = (tk[m] - t0b) / 64.0
            e = np.exp(-2 * D * tau); y = sp[m] ** 2 - (vzb - G * tau) ** 2
            h02 = np.sum(y * e) / np.sum(e * e)
            if h02 <= 0: continue
            rr = np.sqrt(np.mean((np.sqrt(h02 * e + (vzb - G * tau) ** 2) - sp[m]) ** 2))
            if bf is None or rr < bf[0]: bf = (rr, t0b, vzb, np.sqrt(h02))
    # pre-jump ground speed: linear trend of the last samples before J (ground), evaluated at t0
    g = (tk >= J - 6) & (tk <= J + 0.2)
    if g.sum() >= 2:
        c = np.polyfit(tk[g], sp[g], 1); vg = np.polyval(c, t0); vgJ = np.polyval(c, J)
    else:
        vg = vgJ = np.nan
    # apex: HUD minimum within the flight
    m = (tk > t0 + 3) & (tk < t1 - 3)
    k = np.argmin(sp[m]); hmin = sp[m][k]; tmin = tk[m][k]
    # h at the minimum: HUD^2 = h^2 + vz^2 with vz = -D h^2/G at the minimum
    ha = hmin
    for _ in range(5): ha = np.sqrt(max(hmin ** 2 - (D * ha * ha / G) ** 2, 0))
    h0_apex = ha * np.exp(D * (vz0 / G + D * ha * ha / G / G))  # apex at vz = 0 is vz0/G after t0; the min a bit later
    # landing: model h at t1 vs the first ground HUD samples after the landing ramp
    h_land = h0 * np.exp(-D * (t1 - t0) / 64)
    post = (tk > t1 + 1.2) & (tk < t1 + 6)
    v_post = np.polyval(np.polyfit(tk[post], sp[post], 1), t1) if post.sum() >= 2 else np.nan
    return dict(t0=t0, t1=t1, T=t1 - t0, vz0=vz0, h0=h0, rms=r, vg=vg, vgJ=vgJ, h0_apex=h0_apex, tmin=tmin,
                free=bf, h_land=h_land, v_post=v_post)
if __name__ == "__main__":
    a = sys.argv[1:]
    print("%-7s %-5s %6s %6s %5s %6s %6s %5s %6s %6s %5s | %-22s | %6s %6s %5s" % ("scen", "trial", "t0", "T", "vz0", "vg(t0)", "h0", "rms", "ratio", "h0apx", "r_apx",
          "free t0/vz0/h0/rms", "hLand", "vPost", "land"))
    for i in range(0, len(a), 3):
        st, nm, J = a[i], a[i + 1], float(a[i + 2])
        for p in trials(st, nm):
            f = fit_trial(p, J)
            if f is None: print(nm, "no landing"); continue
            fr = f["free"]
            print("%-7s %-5s %6.1f %6.1f %5.0f %6.0f %6.1f %5.1f %6.3f %6.1f %5.3f | %5.1f %4.0f %5.1f %4.1f | %6.1f %6.1f %5.3f" % (
                nm, os.path.basename(p)[:6], f["t0"], f["T"], f["vz0"], f["vg"], f["h0"], f["rms"], f["h0"] / f["vg"],
                f["h0_apex"], f["h0_apex"] / f["vg"], fr[1], fr[2], fr[3], fr[0], f["h_land"], f["v_post"], f["v_post"] / f["h_land"]))

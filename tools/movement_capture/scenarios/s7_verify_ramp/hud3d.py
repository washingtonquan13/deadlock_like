# Verifier: is the HUD 3D or horizontal speed on the ramp? Compare HUD vs camera-derived speeds.
import sys, glob, csv, numpy as np
ROOT = "C:/Godot Projects/deadlock_like/deadlock_like/tools/movement_capture/rec_auto/s7_ramp/"
def load(f):
    rows = [r for r in csv.DictReader(open(f)) if r["valid"] == "1"]
    D = {}
    for k in ("t","pos_x","pos_y","pos_z","vel_scalar","ang_pitch","ang_yaw"):
        D[k] = np.array([float(r[k]) if r[k] else np.nan for r in rows])
    class O: pass
    o = O(); o.__dict__.update(D); o.__getitem__ = None
    return D
def deriv(t, x, w=0.08):
    out = np.full(len(t), np.nan)
    for i in range(len(t)):
        m = np.abs(t - t[i]) <= w
        if m.sum() >= 4 and np.ptp(t[m]) > w:
            out[i] = np.polyfit(t[m], x[m], 1)[0]
    return out
for name in sys.argv[1:]:
    for f in sorted(glob.glob(ROOT + name + "/*t[123].csv"))[:3]:
        d = load(f); t = d['t']
        vx, vy, vz = (deriv(t, d[c]) for c in ("pos_x", "pos_y", "pos_z"))
        vh = np.hypot(vx, vy); v3 = np.sqrt(vh**2 + vz**2)
        hud = d['vel_scalar']
        print(f"== {name} {f.split('/')[-1]}  pitch range {np.nanmin(d['ang_pitch']):.1f}..{np.nanmax(d['ang_pitch']):.1f} yaw {np.nanmin(d['ang_yaw']):.1f}..{np.nanmax(d['ang_yaw']):.1f}")
        # compare HUD at t+lag to derived at t
        for lag in (0.0, 0.03, 0.06, 0.09):
            hl = np.interp(t + lag, t, hud)
            m = (np.abs(vz) > 80) & (vh > 150) & np.isfinite(vz)
            if m.sum():
                print(f"  lag {lag:.2f}: n={m.sum()} med(HUD-vh)={np.median(hl[m]-vh[m]):7.1f}  med(HUD-v3)={np.median(hl[m]-v3[m]):7.1f}  med vz={np.median(vz[m]):.0f}")
        for i in range(0, len(t), max(1, len(t)//40)):
            print(f"   t={t[i]:5.2f} z={d['pos_z'][i]:7.1f} vh={vh[i]:6.0f} vz={vz[i]:6.0f} v3={v3[i]:6.0f} HUD={hud[i]:6.0f}")
        break

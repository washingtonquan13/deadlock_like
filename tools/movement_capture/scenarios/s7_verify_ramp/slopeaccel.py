# Verifier: net horizontal accel on the slope from the HUD (HUD = horizontal speed on the ground).
# Slope window = camera z between (top - 8 - crouch_off) and (bottom + 8) after the crouch camera drop has settled.
import sys, glob, csv, numpy as np
ROOT = "C:/Godot Projects/deadlock_like/deadlock_like/tools/movement_capture/rec_auto/s7_ramp/"
TOP, BOT, CR = 130.0, 2.0, 28.7   # standing camera z top/bottom; crouch lowers camera ~28.7
def load(f):
    rows = [r for r in csv.DictReader(open(f)) if r["valid"] == "1"]
    g = lambda k: np.array([float(r[k]) if r[k] else np.nan for r in rows])
    return g("t"), g("pos_z"), g("vel_scalar")
def fit(name, t_settle, crouched=True, lag=0.06):
    for f in sorted(glob.glob(ROOT + name + "/*t[123].csv")):
        t, z, h = load(f)
        off = CR if crouched else 0.0
        tb = t[np.argmax(z < BOT - off + 10)]
        m = (t > t_settle) & (t < tb) & (z < TOP - off - 10) & (z > BOT - off + 10) & np.isfinite(h)
        # HUD lags ~lag s: use HUD samples shifted back
        tt = t[m] - lag
        if m.sum() < 5: print(name, f[-12:], "too few"); continue
        a, b = np.polyfit(tt, h[m], 1)
        # quadratic-free check: split halves
        mid = np.median(tt)
        a1 = np.polyfit(tt[tt <= mid], h[m][tt <= mid], 1)[0]; a2 = np.polyfit(tt[tt > mid], h[m][tt > mid], 1)[0]
        print(f"{name:6s} {f.split(chr(92))[-1][:10]:10s} window {tt.min():.2f}-{tt.max():.2f}s  HUD {h[m].min():.0f}-{h[m].max():.0f}  mean {h[m].mean():.0f}  net accel {a:6.0f}  (halves {a1:.0f}/{a2:.0f})")
g_tan = 800 * np.tan(np.radians(26.5))
print(f"g*tan(26.5) = {g_tan:.0f}")
fit("RRUN", 0.80)
fit("RBOT", 1.25)
fit("RDASH", 0.45)
fit("RWALK", 0.7, crouched=False)

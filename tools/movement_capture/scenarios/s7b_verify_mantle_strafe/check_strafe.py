# independent verifier: strafe/diagonal run speed from s7_open FSW/FSD/FSA/FSWA
import csv, glob, math, os, sys
import numpy as np
ROOT = os.path.join(os.path.dirname(__file__), '..', '..', 'rec_auto', 's7_open')
def load(p):
    R = [r for r in csv.DictReader(open(p)) if r['valid'] == '1']
    f = lambda k: np.array([float(r[k]) if r[k] != '' else np.nan for r in R])
    return f('t'), f('pos_x'), f('pos_y'), f('pos_z'), f('vel_scalar'), f('ang_yaw')
for name in ['FSW', 'FSD', 'FSA', 'FSWA']:
    for p in sorted(glob.glob(os.path.join(ROOT, name, '*.csv'))):
        t, x, y, z, hud, yaw = load(p)
        def at(tt):
            i = np.argmin(abs(t - tt)); return hud[i]
        def cross(v):
            i = np.where(hud >= v)[0]
            if not len(i): return None
            i = i[0]; return t[i-1] + (v - hud[i-1]) * (t[i] - t[i-1]) / (hud[i] - hud[i-1])
        # position-derived horizontal speed over 1.2..2.4 s window
        m = (t > 1.3) & (t < 1.9)
        A = np.polyfit(t[m], x[m], 1)[0]; B = np.polyfit(t[m], y[m], 1)[0]
        sp = math.hypot(A, B)
        ang = math.degrees(math.atan2(B, A)); rel = ((ang - yaw[0] + 180) % 360) - 180
        zr = np.nanmax(z[(t > 0) & (t < 2.5)]) - np.nanmin(z[(t > 0) & (t < 2.5)])
        plateau = np.nanmedian(hud[m])
        print(f"{name} {os.path.basename(p)} hud@.2/.4/.6/.8/1.0/1.5/2.0 = " +
              " ".join(f"{at(q):.0f}" for q in [.2, .4, .6, .8, 1.0, 1.5, 2.0]) +
              f" | x300 {cross(300):.3f} x380 {cross(380):.3f} | plateauHUD {plateau:.1f} posfit {sp:.1f} dir_rel_yaw {rel:+.0f} zrange {zr:.1f} yaw0 {yaw[0]:.1f} yawspan {np.nanmax(yaw)-np.nanmin(yaw):.2f}")

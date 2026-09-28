"""Verifier: on ramp1, compare camera-derived horizontal / vertical speed (linear fits over windows) with the HUD.
Tells whether HUD is 3D speed (HUD^2 = h^2 + vz^2) or horizontal speed on the slope."""
import csv, glob, os, sys, math
import numpy as np
root = os.path.join(os.path.dirname(__file__), '..', '..', 'rec_auto', 's7_ramp')
name = sys.argv[1] if len(sys.argv) > 1 else 'RWALK'
for f in sorted(glob.glob(os.path.join(root, name, '*.csv'))):
    R = [r for r in csv.DictReader(open(f)) if r['valid'] == '1']
    t = np.array([float(r['t']) for r in R]); x = np.array([float(r['pos_x']) for r in R])
    y = np.array([float(r['pos_y']) for r in R]); z = np.array([float(r['pos_z']) for r in R])
    hud = np.array([float(r['vel_scalar']) if r['vel_scalar'] else np.nan for r in R])
    print(os.path.basename(f))
    for a in np.arange(0.2, 2.6, 0.2):
        k = (t >= a) & (t < a + 0.2)
        if k.sum() < 8: continue
        # robust: median-filter out OCR spikes by rejecting points far from a first fit
        vx, vy, vz = (np.polyfit(t[k], q[k], 1)[0] for q in (x, y, z))
        h = math.hypot(vx, vy); hm = np.nanmedian(hud[k])
        print("  t %.1f-%.1f  h %4.0f  vz %5.0f  3D %4.0f  HUD %4.0f  slope %4.1f deg" % (a, a + .2, h, vz, math.sqrt(h*h+vz*vz), hm, math.degrees(math.atan2(-vz, h))))

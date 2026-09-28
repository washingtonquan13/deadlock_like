"""s7 ramp: fit the downhill slide acceleration from the raw HUD (run from tools/movement_capture).
For each trial, the HUD speed in a window on the slope is fitted with a line (net accel) and with
dv/dt = a - k v for fixed k (k = normal 0.1875 / dash 0.694 / 0), printing a. Also the ratio of the
camera-track horizontal distance to the HUD integral (1.0 = HUD is horizontal speed, 0.90 = HUD is 3D)."""
import sys, os, glob
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "s7_ramp"))
os.environ["MARK"] = "ramp1_top"
import ana

WIN = {  # HUD-time windows fully on the slope, sliding (after the entry transient, before the bottom)
    "RBOT": (1.06, 1.19), "RRUN": (0.84, 1.17), "RDASH": (0.45, 0.64), "RRUN/outlier": (0.60, 1.05),
}
for name, (t0, t1) in WIN.items():
    k0 = 0.694 if name == "RDASH" else 0.1875
    for p in sorted(glob.glob("rec_auto/s7_ramp/%s/*.csv" % name)):
        t, d, lat, z, sp = ana.load(p)
        m = (t >= t0) & (t <= t1)
        tt, vv = t[m], sp[m]
        slope, icpt = np.polyfit(tt, vv, 1)
        vm = vv.mean()
        # horizontal distance from the camera track vs HUD integral
        i0, i1 = np.where(m)[0][[0, -1]]
        dist = np.hypot(d[i1] - d[i0], lat[i1] - lat[i0])
        integ = np.trapezoid(vv, tt)
        print("%-14s %-14s net %6.0f u/s^2 at v %5.0f | a(k=%.3f) %5.0f  a(k=0.1875) %5.0f | dist/HUDint %.3f" % (
            name, os.path.basename(p), slope, vm, k0, slope + k0 * vm, slope + 0.1875 * vm, dist / integ))

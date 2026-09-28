"""Summarise slide-steer trials: readout speed, hero heading (camera offset rotated out), yaw, lateral drift."""
import csv, json, math, sys, glob, os
import numpy as np
mark = json.load(open("driver/marks.json"))["street"]
o0 = np.array(mark["cam_offset"][:2]); yaw0 = mark["yaw"]
def load(p):
    R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
    f = lambda k: np.array([float(r[k]) if r[k] else np.nan for r in R])
    return f("t"), f("pos_x"), f("pos_y"), f("vel_scalar"), f("ang_yaw")
def hero(x, y, yaw):
    a = np.radians(yaw - yaw0); c, s = np.cos(a), np.sin(a)
    ox = c * o0[0] - s * o0[1]; oy = s * o0[0] + c * o0[1]
    return x - ox, y - oy
step = float(sys.argv[2]) if len(sys.argv) > 2 else 0.1
for p in sorted(glob.glob(os.path.join(sys.argv[1], "*.csv"))):
    t, x, y, sp, yaw = load(p)
    hx, hy = hero(x, y, yaw)
    h0 = math.radians(yaw0)
    print("==", p, " peak speed %.1f" % np.nanmax(sp))
    print("   t    speed   yaw    heading  fwd_m  lat_m(+left)")
    for tt in np.arange(0.0, t[-1], step):
        i = np.searchsorted(t, tt)
        j0, j1 = np.searchsorted(t, tt - 0.04), np.searchsorted(t, tt + 0.04)
        j1 = min(j1, len(t) - 1)
        if i >= len(t) or j1 <= j0: continue
        dx, dy = hx[j1] - hx[j0], hy[j1] - hy[j0]
        hd = math.degrees(math.atan2(dy, dx)) if math.hypot(dx, dy) > 2 else float("nan")
        rx, ry = hx[i] - hx[0], hy[i] - hy[0]
        fwd = (rx * math.cos(h0) + ry * math.sin(h0)) * 0.0254
        lat = (-rx * math.sin(h0) + ry * math.cos(h0)) * 0.0254
        print("%5.2f %7.1f %7.2f %8.1f %6.2f %6.2f" % (t[i], sp[i], yaw[i], hd, fwd, lat))

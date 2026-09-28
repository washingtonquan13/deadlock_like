"""Wall trials: hero position (camera offset rotated out) relative to the start, in m, along the mark's
facing (fwd) and to its left (lat), plus height and finite-difference velocities in u/s."""
import csv, json, math, sys, glob, os
import numpy as np
mark = json.load(open("driver/marks.json"))[os.environ.get("MARK", "wallA")]
o0 = np.array(mark["cam_offset"][:2]); yaw0 = mark["yaw"]
def load(p):
    R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
    f = lambda k: np.array([float(r[k]) if r[k] else np.nan for r in R])
    return f("t"), f("pos_x"), f("pos_y"), f("pos_z"), f("vel_scalar"), f("ang_yaw")
def track(p):
    t, x, y, z, sp, yaw = load(p)
    a = np.radians(yaw - yaw0); c, s = np.cos(a), np.sin(a)
    hx = x - (c * o0[0] - s * o0[1]); hy = y - (s * o0[0] + c * o0[1])
    h0 = math.radians(float(os.environ.get("FRAMEYAW", yaw0))); rx, ry = hx - hx[0], hy - hy[0]
    fwd = rx * math.cos(h0) + ry * math.sin(h0); lat = -rx * math.sin(h0) + ry * math.cos(h0)
    return t, fwd, lat, z - z[0], sp, yaw
def vel(t, q, tt, w=0.03):
    j0, j1 = np.searchsorted(t, tt - w), min(np.searchsorted(t, tt + w), len(t) - 1)
    return (q[j1] - q[j0]) / (t[j1] - t[j0]) if j1 > j0 and t[j1] > t[j0] else float("nan")
if __name__ == "__main__":
    step = float(sys.argv[2]) if len(sys.argv) > 2 else 0.05
    t0 = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
    for p in sorted(glob.glob(os.path.join(sys.argv[1], "*.csv"))):
        t, fwd, lat, z, sp, yaw = track(p)
        print("==", p)
        print("   t   hud_sp  fwd_m  lat_m   z_m   v_fwd  v_lat   v_z   yaw")
        for tt in np.arange(t0, t[-1], step):
            i = min(np.searchsorted(t, tt), len(t) - 1)
            print("%5.2f %7.1f %6.2f %6.2f %5.2f %7.1f %6.1f %6.1f %6.2f" % (t[i], sp[i], fwd[i] * .0254, lat[i] * .0254,
                  z[i] * .0254, vel(t, fwd, tt), vel(t, lat, tt), vel(t, z, tt), yaw[i]))

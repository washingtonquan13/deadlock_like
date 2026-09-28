"""Session 6 diagonal-air analysis helpers (clean room: HUD + cl_showpos camera only).
load(dir) -> list of trials (tick, fwd, left, up, hud); camera displacement projected on the start yaw
(left = +90 deg, so D moves toward negative left). vel(tr, a, b) = linear-fit slope (u/s) over ticks a..b.
Usage: ana.py DIR [DIR...] -> per-axis velocities every 8 ticks."""
import sys, os, csv, json, glob, math, numpy as np

MC = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def load(d):
    d = d if os.path.isabs(d) else os.path.join(MC, d)
    out = []
    for p in sorted(glob.glob(os.path.join(d, "*.csv"))):
        meta = json.load(open(p[:-4] + "_inputs.json"))
        yaw = math.radians(meta["start_yaw"])
        r = [x for x in csv.DictReader(open(p)) if x.get("valid", "1") == "1" and x["vel_scalar"] and x["pos_x"]]
        t = np.array([float(x["t"]) for x in r]) * 64 + 1
        P = np.array([[float(x["pos_x"]), float(x["pos_y"]), float(x["pos_z"])] for x in r]); P -= P[0]
        f = P[:, 0] * math.cos(yaw) + P[:, 1] * math.sin(yaw)
        l = -P[:, 0] * math.sin(yaw) + P[:, 1] * math.cos(yaw)
        out.append({"name": os.path.basename(d) + "/" + os.path.basename(p)[:-4], "t": t, "f": f, "l": l, "z": P[:, 2],
                    "hud": np.array([float(x["vel_scalar"]) for x in r])})
    return out


def vel(tr, a, b, key):
    m = (tr["t"] >= a) & (tr["t"] <= b)
    return np.polyfit(tr["t"][m] / 64.0, tr[key][m], 1)[0] if m.sum() >= 3 else float("nan")


def at(tr, k, key):
    return float(np.interp(k, tr["t"], tr[key]))


if __name__ == "__main__":
    for d in sys.argv[1:]:
        for tr in load(d):
            print(tr["name"])
            for a in range(30, 200, 8):
                print("  %3d-%3d vf %7.1f vl %7.1f vz %7.1f | f %7.1f l %7.1f z %6.1f hud %6.1f" % (
                    a, a + 8, vel(tr, a, a + 8, "f"), vel(tr, a, a + 8, "l"), vel(tr, a, a + 8, "z"),
                    at(tr, a + 4, "f"), at(tr, a + 4, "l"), at(tr, a + 4, "z"), at(tr, a + 4, "hud")))

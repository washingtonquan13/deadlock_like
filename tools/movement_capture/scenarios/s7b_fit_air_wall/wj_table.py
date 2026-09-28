"""Wall-jump tangential table, game side. Frame: fwd = +x (into wallA's wall, normal -x), lat = +y (left).
For each trial: the kick frame (first frame after the press where fwd speed turns negative), the tangential speed
just before it (slope of lat over the last 0.035 s before the kick) and the launch (drag-corrected least squares over
0.45 s after the kick, as scenarios/wall/fitwj.py). Rows: set/name, key, pre_lat, post_lat, post_fwd.
Usage (from tools/movement_capture): .venv/Scripts/python.exe scenarios/s7b_fit_air_wall/wj_table.py"""
import sys, os, glob, json
import numpy as np
os.environ["FRAMEYAW"] = "0.03"
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "wall"))
import importlib
DRAG, G, W = 0.2, 800.0, 0.45
CASES = [("s7_open", "WJD", "wallA"), ("s7_open", "WJA", "wallA"), ("wall", "WJD", "wallA"), ("wall", "WJA", "wallA"),
         ("wall", "WJ0", "wallA"), ("wall", "WJW", "wallA"), ("wall", "WJS", "wallA"), ("wall", "WJWA", "wallA"),
         ("wall", "WJSA", "wallA"), ("wall", "AWJ0", "wallA25"), ("wall", "BWJ0", "wallA45"), ("wall", "BWJS", "wallA45")]
out = []
for st, n, mark in CASES:
    os.environ["MARK"] = mark
    import analyze; importlib.reload(analyze)
    sc = json.load(open("scenarios/%s/%s.json" % (st, n)))
    press = [e["from"] for e in sc["timeline"] if "jump" in e.get("buttons", [])][-1]
    keys = [e.get("move") for e in sc["timeline"] if e.get("from", 0) > 60 and "move" in e]
    for p in sorted(glob.glob("rec_auto/%s/%s/ts1_t*.csv" % (st, n))):
        t, fwd, lat, z, sp, yaw = analyze.track(p)
        tp = (press - 1) / 64.0
        vf = np.r_[0, np.diff(fwd) / np.maximum(np.diff(t), 1e-4)]
        after = t > tp
        k = np.argmax(after & (vf < -60))
        if not after[k]: print(n, "no kick"); continue
        mp = (t < t[k] - 0.002) & (t > t[k] - 0.037)
        pre_lat = np.polyfit(t[mp], lat[mp], 1)[0] if mp.sum() >= 2 else np.nan
        pre_fwd = np.polyfit(t[mp], fwd[mp], 1)[0] if mp.sum() >= 2 else np.nan
        tj = t[k] - 0.5 / 64
        m = (t >= t[k]) & (t <= tj + W)
        tau = t[m] - tj; e = (1 - np.exp(-DRAG * tau)) / DRAG
        vfl = np.linalg.lstsq(np.c_[np.ones_like(e), e], fwd[m], rcond=None)[0][1]
        vl = np.linalg.lstsq(np.c_[np.ones_like(e), e], lat[m], rcond=None)[0][1]
        out.append((st, n, os.path.basename(p)[4:6], keys[0] if keys else None, pre_lat, pre_fwd, vl, vfl))
        print("%-8s %-5s %s key %-9s | pre lat %7.1f fwd %7.1f | post lat %7.1f fwd %7.1f" % out[-1])
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "wj_table.json"), "w"))

"""Camera displacement extents (forward/left along the mark yaw) of existing recordings, per mark.
Run from tools/movement_capture: .venv/Scripts/python.exe scenarios/s6_airdash/extents.py [glob...]"""
import csv, glob, json, math, sys
pats = sys.argv[1:] or ["rec_auto/dj148/*/*_t1.csv", "rec_auto/stam/*/*_t1.csv", "rec_auto/route/*/*_t1.csv",
                        "rec_auto/double/*/*_t1.csv", "rec_auto/sback/*/*_t1.csv", "rec_auto/lslide/*/*_t1.csv", "rec_auto/hop/*/*_t1.csv"]
for pat in pats:
    for f in sorted(glob.glob(pat)):
        try:
            inp = json.load(open(f.replace(".csv", "_inputs.json")))
        except Exception:
            continue
        yaw = math.radians(inp["start_yaw"]); fx, fy = math.cos(yaw), math.sin(yaw)
        rs = [r for r in csv.DictReader(open(f)) if r["valid"] == "1"]
        x0, y0 = float(rs[0]["pos_x"]), float(rs[0]["pos_y"])
        fw = [(float(r["pos_x"]) - x0) * fx + (float(r["pos_y"]) - y0) * fy for r in rs]
        lf = [-(float(r["pos_x"]) - x0) * fy + (float(r["pos_y"]) - y0) * fx for r in rs]
        vmax = max(float(r["vel_scalar"] or 0) for r in rs)
        print("%-40s %-12s ts%-4g fwd %7.0f..%6.0f  left %6.0f..%6.0f  HUDmax %5.0f" % (
            f[9:], inp.get("mark"), inp.get("timescale", 1), min(fw), max(fw), min(lf), max(lf), vmax))

"""Summary of a route_export CSV: extents, loco sequence, entry v_par/perp at the air dash and its peak."""
import csv, math, sys
rs = list(csv.DictReader(open(sys.argv[1])))
f = [float(r["fwd"]) for r in rs]; l = [float(r["left"]) for r in rs]; u = [float(r["up"]) for r in rs]
seq = []
for r in rs:
    if not seq or seq[-1][0] != r["loco"]:
        seq.append((r["loco"], int(r["tick"])))
print("  extents fwd %.0f..%.0f left %.0f..%.0f up max %.0f" % (min(f), max(f), min(l), max(l), max(u)))
print("  loco", " ".join("%s@%d" % s for s in seq))
ad = [i for i, r in enumerate(rs) if r["loco"] == "AIR_DASH"]
if ad:
    i = ad[0]
    vx = (f[i - 1] - f[i - 2]) * 64; vy = (l[i - 1] - l[i - 2]) * 64
    pk = max(ad, key=lambda k: float(rs[k]["speed_h"]))
    print("  air dash ticks %d..%d  pre-dash v fwd %.0f left %.0f  h %.0f -> peak %.1f at +%d  end h %.1f  land fwd %.0f" % (
        ad[0], ad[-1], vx, vy, float(rs[i - 1]["speed_h"]), float(rs[pk]["speed_h"]), pk - i, float(rs[ad[-1]]["speed_h"]),
        next((f[k] for k in range(ad[-1], len(rs)) if rs[k]["loco"] not in ("AIR", "AIR_DASH")), float("nan"))))
else:
    print("  NO AIR DASH in the sim")

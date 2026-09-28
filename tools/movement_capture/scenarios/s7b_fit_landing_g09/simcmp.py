"""Sim traces (run_sim.sh TAG): per takeoff/landing, h before/after; per flight, h at vz~0 (apex) and last-air h.
Usage: simcmp.py TAG [TAG...]"""
import sys, csv, os
D = os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", "tools_fit", "_out", "s7b_landing_g09")
NAMES = ["LT465", "LT460", "LT450", "LT440", "SHH6", "SHH12", "SHH20", "SHH30", "SHH40", "SHH6F"]
for tag in sys.argv[1:]:
    print("==", tag)
    for n in NAMES:
        p = os.path.join(D, "%s_%s.csv" % (tag, n))
        if not os.path.exists(p): continue
        rows = list(csv.DictReader(open(p))); out = []; apex = None
        for a, b in zip(rows, rows[1:]):
            air_a, air_b = a["loco"].startswith("AIR"), b["loco"].startswith("AIR")
            if air_a and not air_b:
                out.append("land@%s %s %.1f->%.1f (%.3f)" % (b["tick"], b["loco"], float(a["speed_h"]), float(b["speed_h"]), float(b["speed_h"]) / max(1e-6, float(a["speed_h"]))))
            if not air_a and air_b:
                out.append("off@%s %.1f->%.1f vz %.0f" % (b["tick"], float(a["speed_h"]), float(b["speed_h"]), float(b["vel_v"])))
                apex = True
            if air_a and air_b and apex and float(a["vel_v"]) > 0 >= float(b["vel_v"]):
                out.append("apex@%s %.1f" % (b["tick"], float(b["speed_h"]))); apex = None
        print("%-6s %s" % (n, " | ".join(out)))

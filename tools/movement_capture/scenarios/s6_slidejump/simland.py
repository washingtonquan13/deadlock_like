"""Sim landings from route_export CSVs: h on the last air tick, h on the first ground tick, ratio.
Usage: simland.py DIR NAME..."""
import sys, csv, os
d = sys.argv[1]
for n in sys.argv[2:]:
    rows = list(csv.DictReader(open(os.path.join(d, n + ".csv"))))
    out = []
    for a, b in zip(rows, rows[1:]):
        if a["loco"] in ("AIR",) and b["loco"] != "AIR":
            out.append("land@%s %s %.1f->%.1f (%.3f)" % (b["tick"], b["loco"], float(a["speed_h"]), float(b["speed_h"]), float(b["speed_h"]) / float(a["speed_h"])))
        if a["loco"] != "AIR" and b["loco"] == "AIR":
            out.append("takeoff@%s %.1f->%.1f" % (b["tick"], float(a["speed_h"]), float(b["speed_h"])))
    print("%-6s %s" % (n, " | ".join(out)))

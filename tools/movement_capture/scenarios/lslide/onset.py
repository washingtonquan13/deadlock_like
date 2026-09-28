"""Slide penalty onset: first tick after START where the HUD speed falls faster than RATE (1/s) over ~3 ticks.
Usage: onset.py START CSV..."""
import csv, sys, math
start = float(sys.argv[1])
for p in sys.argv[2:]:
    R = [(float(r["t"]) * 64 + 1, float(r["vel_scalar"])) for r in csv.DictReader(open(p)) if r["valid"] == "1" and r["vel_scalar"]]
    R = [x for x in R if x[0] >= start and x[1] > 20]
    on = None
    for i in range(len(R)):
        j = next((j for j in range(i + 1, len(R)) if R[j][0] - R[i][0] >= 2.5), None)
        if j is None: break
        r = math.log(R[i][1] / R[j][1]) / ((R[j][0] - R[i][0]) / 64)
        if r > 1.5:
            on = R[i]; break
    print("%-36s onset %s" % (p, "none" if on is None else "%.1f at %.0f u/s" % on))

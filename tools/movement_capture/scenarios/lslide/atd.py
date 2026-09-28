"""Tick at which the camera first passes horizontal distance D (u). Usage: atd.py D CSV..."""
import csv, sys, math
D = float(sys.argv[1])
for p in sys.argv[2:]:
    R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1" and r["pos_x"]]
    x0, y0 = float(R[0]["pos_x"]), float(R[0]["pos_y"])
    r = next((r for r in R if math.hypot(float(r["pos_x"]) - x0, float(r["pos_y"]) - y0) >= D), None)
    print("%-36s %s" % (p, "never" if r is None else "tick %.1f" % (float(r["t"]) * 64 + 1)))

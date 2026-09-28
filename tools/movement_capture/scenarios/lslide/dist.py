"""Horizontal camera distance from the start (u) at given ticks. Usage: dist.py CSV TICK [TICK...]"""
import csv, sys, math
R = [r for r in csv.DictReader(open(sys.argv[1])) if r["valid"] == "1" and r["pos_x"]]
x0, y0 = float(R[0]["pos_x"]), float(R[0]["pos_y"])
for tk in map(float, sys.argv[2:]):
    r = min(R, key=lambda r: abs(float(r["t"]) * 64 + 1 - tk))
    print("%-34s tick %5.1f  d %6.1f  z %6.1f" % (sys.argv[1], float(r["t"]) * 64 + 1, math.hypot(float(r["pos_x"]) - x0, float(r["pos_y"]) - y0), float(r["pos_z"])))

"""Print tick, HUD 3D speed and camera z (rel. to start) every N ticks. Usage: ser.py CSV [N] [t0tick] [t1tick]"""
import sys, csv
rows = [r for r in csv.DictReader(open(sys.argv[1])) if r["valid"] == "1"]
n = int(sys.argv[2]) if len(sys.argv) > 2 else 3
a = int(sys.argv[3]) if len(sys.argv) > 3 else 0; b = int(sys.argv[4]) if len(sys.argv) > 4 else 10**9
z0 = float(rows[0]["pos_z"]); last = -99
out = []
for r in rows:
    tk = float(r["t"]) * 64 + 1
    if tk < a or tk > b or tk - last < n: continue
    last = tk; out.append("%5.1f:%4.0f/%4.0f" % (tk, float(r["vel_scalar"]), float(r["pos_z"]) - z0))
for i in range(0, len(out), 6): print("  ".join(out[i:i + 6]))

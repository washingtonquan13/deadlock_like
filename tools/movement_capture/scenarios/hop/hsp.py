"""Horizontal speed after a jump from HUD 3D speed: h = sqrt(sp^2 - vz^2), vz = V0 - g*(t - tj) (V0 300, g 800).
Usage: hsp.py CSV JUMPTICK [T1TICK]"""
import sys, csv, math
rows = [r for r in csv.DictReader(open(sys.argv[1])) if r["valid"] == "1"]
tj = int(sys.argv[2]); t1 = int(sys.argv[3]) if len(sys.argv) > 3 else tj + 40
out = []
for r in rows:
    tk = float(r["t"]) * 64 + 1
    if tk < tj - 4 or tk > t1: continue
    sp = float(r["vel_scalar"]); vz = 300 - 800 * max(0.0, tk - tj) / 64 if tk >= tj else 0.0
    out.append("%5.1f:%4.0f" % (tk, math.sqrt(max(sp * sp - vz * vz, 0))))
for i in range(0, len(out), 10): print("  ".join(out[i:i + 10]))

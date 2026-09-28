"""tick, HUD speed, fwd, vz (camera differences over ~3 ticks) from A to B. Usage: ser.py YAW A B CSV"""
import csv, sys, math
yaw = math.radians(float(sys.argv[1])); A, B = float(sys.argv[2]), float(sys.argv[3]); fx, fy = math.cos(yaw), math.sin(yaw)
R = [r for r in csv.DictReader(open(sys.argv[4])) if r["valid"] == "1" and r["pos_x"]]
T = [float(r["t"]) * 64 + 1 for r in R]; X = [float(r["pos_x"]) for r in R]; Y = [float(r["pos_y"]) for r in R]; Z = [float(r["pos_z"]) for r in R]
out = []
for i in range(len(R)):
    if not A <= T[i] <= B: continue
    j = next((j for j in range(i + 1, len(R)) if T[j] - T[i] >= 3), None)
    if j is None: break
    dt = (T[j] - T[i]) / 64
    out.append("%5.1f %4s %5.0f %5.0f z%5.0f" % (T[i], R[i]["vel_scalar"][:4] if R[i]["vel_scalar"] else "-", ((X[j] - X[i]) * fx + (Y[j] - Y[i]) * fy) / dt, (Z[j] - Z[i]) / dt, Z[i]))
for k in range(0, len(out), 4): print("  |  ".join(out[k:k + 4]))

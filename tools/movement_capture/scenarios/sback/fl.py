"""HUD speed plus forward/lateral velocity (u/s, camera differences; the yaw is fixed so the camera offset cancels).
Usage: fl.py YAW STEP CSV..."""
import csv, sys, math
yaw = math.radians(float(sys.argv[1])); step = int(sys.argv[2])
fx, fy = math.cos(yaw), math.sin(yaw)
for p in sys.argv[3:]:
    R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1" and r["pos_x"] and r["vel_scalar"]]
    T = [float(r["t"]) * 64 + 1 for r in R]; X = [float(r["pos_x"]) for r in R]; Y = [float(r["pos_y"]) for r in R]
    print("==", p); out = []
    for i in range(0, len(R), step):
        j = next((j for j in range(i + 1, len(R)) if T[j] - T[i] >= 3), None)
        if j is None: break
        dt = (T[j] - T[i]) / 64; vx = (X[j] - X[i]) / dt; vy = (Y[j] - Y[i]) / dt
        out.append("%5.0f %4.0f %5.0f %4.0f" % (T[i], float(R[i]["vel_scalar"]), vx * fx + vy * fy, -vx * fy + vy * fx))
    for k in range(0, len(out), 4):
        print("  |  ".join(out[k:k + 4]))

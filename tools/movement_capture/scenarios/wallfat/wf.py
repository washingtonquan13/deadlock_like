"""Forward (toward the wall, +) and vertical velocity from camera differences (~3 ticks) around each jump.
Prints each vz step > 150 u/s: tick, fwd and vz before (~6 ticks earlier) and after (~6 ticks later).
Usage: wf.py YAW CSV..."""
import csv, sys, math
yaw = math.radians(float(sys.argv[1])); fx, fy = math.cos(yaw), math.sin(yaw)
for p in sys.argv[2:]:
    R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1" and r["pos_x"]]
    T = [float(r["t"]) * 64 + 1 for r in R]; X = [float(r["pos_x"]) for r in R]; Y = [float(r["pos_y"]) for r in R]; Z = [float(r["pos_z"]) for r in R]
    V = []
    for i in range(len(R)):
        j = next((j for j in range(i + 1, len(R)) if T[j] - T[i] >= 3), None)
        if j is None: break
        dt = (T[j] - T[i]) / 64
        V.append((T[i], ((X[j] - X[i]) * fx + (Y[j] - Y[i]) * fy) / dt, (Z[j] - Z[i]) / dt))
    def at(tk):
        return min(V, key=lambda v: abs(v[0] - tk))
    out = []; last = -99
    for k in range(1, len(V)):
        if V[k][2] - V[k - 1][2] > 150 and V[k][0] - last > 15 and V[k][0] > 70:
            b = at(V[k][0] - 7); a = at(V[k][0] + 5)
            out.append("jump ~%5.1f: fwd %5.0f -> %5.0f  vz %5.0f -> %5.0f" % (V[k][0], b[1], a[1], b[2], a[2])); last = V[k][0]
    print("==", p); print("\n".join(out))

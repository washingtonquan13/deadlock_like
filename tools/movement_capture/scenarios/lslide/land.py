"""Landing summary: landing tick, HUD speed over the first ~20 ground ticks, per-tick decay rate (1/s)."""
import csv, sys, math
for p in sys.argv[1:]:
    R = [(float(r["t"]) * 64 + 1, float(r["vel_scalar"]), float(r["pos_z"])) for r in csv.DictReader(open(p))
         if r["valid"] == "1" and r["vel_scalar"]]
    z0 = R[0][2]
    apex = max(range(len(R)), key=lambda i: R[i][2])
    land = next(i for i in range(apex, len(R)) if R[i][2] < z0 - 8)
    g = [(t, v) for t, v, z in R[land:] if t <= R[land][0] + 22]
    g = g[1:]
    rate = math.log(g[0][1] / max(g[-1][1], 1)) / ((g[-1][0] - g[0][0]) / 64)
    print("%-40s land %.1f  %4.0f -> %4.0f in %.0f ticks  rate %.2f/s  %s" % (p, R[land][0], g[0][1], g[-1][1],
          g[-1][0] - g[0][0], rate, "SLIDE" if rate < 1.0 else "brake"))

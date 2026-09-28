import csv, sys, numpy as np, math
p = sys.argv[1]
R = [r for r in csv.DictReader(open(p)) if r['valid'] == '1']
prev = None
for r in R:
    t = float(r['t'])
    if t < -0.05 or t > 2.8: continue
    x, y, z = float(r['pos_x']), float(r['pos_y']), float(r['pos_z'])
    s = ''
    if prev:
        dt = t - prev[0]
        if dt > 0: s = f"{math.hypot(x-prev[1], y-prev[2])/dt:7.1f}"
    prev = (t, x, y)
    print(f"{t:6.3f} {x:9.2f} {y:9.2f} {z:7.2f} hud {r['vel_scalar']:>7} yaw {r['ang_yaw']:>7} dpos {s}")

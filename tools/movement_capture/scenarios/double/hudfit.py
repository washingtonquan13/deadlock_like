"""Horizontal speed after an air jump from the HUD alone. With g fixed (795 u/s^2, measured), over ticks A..B (the rise,
before any contact): HUD^2 - g^2 tau^2 = (h^2 + v0^2) - 2 g v0 tau is linear in tau. Usage: hudfit.py A B CSV..."""
import sys, csv, numpy as np
A, B = int(sys.argv[1]), int(sys.argv[2]); G = 795.0
for p in sys.argv[3:]:
    r = [x for x in csv.DictReader(open(p)) if x.get("valid", "1") == "1" and x["vel_scalar"]]
    t = np.array([float(x["t"]) for x in r]) * 64 + 1; v = np.array([float(x["vel_scalar"]) for x in r])
    m = (t >= A) & (t <= B); tau = (t[m] - A) / 64
    b, a = np.polyfit(tau, v[m] ** 2 - G * G * tau * tau, 1)
    v0 = -b / (2 * G); h = np.sqrt(max(a - v0 * v0, 0))
    res = np.hypot(h, v0 - G * tau) - v[m]
    print("%-40s h %5.1f  vz0 %5.1f  rms %.1f" % (p, h, v0, np.sqrt(np.mean(res ** 2))))

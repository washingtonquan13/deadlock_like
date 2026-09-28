"""vz from camera z (line fit over +-1.5 ticks) and HUD, per tick A..B. Usage: vz.py A B CSV..."""
import sys, csv, numpy as np
A, B = int(sys.argv[1]), int(sys.argv[2])
for p in sys.argv[3:]:
    r = [x for x in csv.DictReader(open(p)) if x["valid"] == "1" and x["pos_z"] and x["vel_scalar"]]
    t = np.array([float(x["t"]) for x in r]) * 64 + 1; z = np.array([float(x["pos_z"]) for x in r]); z -= z[0]
    sp = np.array([float(x["vel_scalar"]) for x in r])
    out = []
    for k in range(A, B + 1):
        m = np.abs(t - k) <= 1.5
        if m.sum() < 3: out.append("%d:--" % k); continue
        vz = np.polyfit(t[m] / 64, z[m], 1)[0]
        out.append("%d:%3.0f/%3.0f z%3.0f" % (k, vz, np.interp(k, t, sp), np.interp(k, t, z)))
    print(p.split("rec_auto/")[-1]); [print("  " + "  ".join(out[i:i + 6])) for i in range(0, len(out), 6)]

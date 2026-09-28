import sys, glob, os, math, numpy as np
sys.argv += []
exec(open("scenarios/slide_steer/analyze.py").read().split("step =")[0])
for s in ["SL0","SLM","SLD","SLWD","SLWM","SLDM"]:
    for p in sorted(glob.glob("rec_auto/slide_steer/%s/*.csv" % s)):
        t, x, y, sp, yaw = load(p)
        hx, hy = hero(x, y, yaw)
        # slide start = speed peak time
        k = np.nanargmax(sp); ts = t[k]
        # penalty onset: first time after ts+0.3 where the 0.05s decay rate exceeds 2/s
        ok = ~np.isnan(sp)
        m = (t > ts + 0.05) & (t < ts + 0.85) & ok
        rate = -np.polyfit(t[m], np.log(sp[m]), 1)[0]
        on = None
        for i in range(k, len(t) - 6):
            if t[i] > ts + 0.3 and sp[i] > 50 and np.log(sp[i] / sp[i + 6]) / (t[i + 6] - t[i]) > 2.0:
                on = t[i] - ts; break
        # heading rate: smoothed heading from positions 0.06 s apart
        hd = []
        for i in range(len(t)):
            j = np.searchsorted(t, t[i] + 0.06)
            if j < len(t) and t[i] > ts + 0.1:
                dx, dy = hx[j] - hx[i], hy[j] - hy[i]
                if math.hypot(dx, dy) > 15: hd.append((t[i], math.degrees(math.atan2(dy, dx))))
        hd = np.array(hd)
        om = float("nan")
        if len(hd):
            m2 = (hd[:, 1] < 97) & (hd[:, 1] > 25) & (hd[:,0] < ts + 1.0)
            if m2.sum() > 5: om = np.polyfit(hd[m2, 0], hd[m2, 1], 1)[0]
        print("%-5s %s  peak %.1f  decay %.3f/s  penalty onset %s  turn %.1f deg/s" % (s, os.path.basename(p)[:6], sp[k], rate, "%.2f s" % on if on else "-", om))

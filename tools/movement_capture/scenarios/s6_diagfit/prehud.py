"""Pre-air-jump horizontal speed from the HUD: HUD minimum between the first jump and the air jump (apex, vz=0),
drag 0.2/s carried to the air-jump HUD step. Usage: prehud.py DIR..."""
import sys, glob, math, numpy as np
for d in sys.argv[1:]:
    for f in sorted(glob.glob(d + "/*_t[0-9].csv")):
        a = np.genfromtxt(f, delimiter=",", names=True)
        a = a[a["valid"] == 1]; t = a["t"]*64+1; h = a["vel_scalar"]
        j = np.where((t > 50) & (np.diff(np.r_[h[0], h]) > 100))[0]
        if not len(j): print(f, "no step"); continue
        tj = t[j[0]]; m = (t > 46) & (t < tj - 0.5)
        k = np.argmin(h[m]); tm, hm = t[m][k], h[m][k]
        print("%-40s apex t %5.1f HUD %6.1f  -> h at tj %5.1f %6.1f   HUD just after step %6.1f" % (f.split("rec_auto/")[1], tm, hm, tj, hm*math.exp(-0.2*(tj-tm)/64), h[j[0]+1]))

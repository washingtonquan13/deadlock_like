"""enddrag.py: per trial, the air dash end drag from the HUD alone. E = first tick after the peak whose HUD step is below
-6 u/s (the end-drag drop; during the dash the drag step is ~-2); pre = HUD at E-1 (vz = 0 in the dash, so HUD = h);
S = first tick after E whose step is > -4 (drop done); h_post = sqrt(HUD(S)^2 - vz^2) with vz = 796*(S-E+1)/64
(gravity assumed to resume with the drop; +-1 tick changes h_post by < 3 u/s here). Drop length = S-E ticks."""
import glob, csv, os, numpy as np
MC = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sets = [("s6_airdash", n, "*.csv") for n in ["E200W", "E386W", "E386WD", "E520W", "E700W", "E700WD", "E386S", "E700S"]]
for b in ("b1", "b2", "b3"):
    for p in ("fast", "whold", "side", "vert", "fall", "back", "slow"):
        sets.append(("A_probe_" + b if p != "fast" else "A_air_" + b, p, None))
print("%-10s %-6s %-5s %4s %7s %7s %4s %7s %6s" % ("set", "case", "trial", "E", "pre", "h_post", "len", "ratio", "drop"))
for s, n, pat in sets:
    fs = sorted(glob.glob(os.path.join(MC, "rec_auto", s, n, pat))) if pat else sorted(glob.glob(os.path.join(MC, "rec_auto", s, n + "_ts*_t[0-9].csv")))
    for f in fs:
        r = [x for x in csv.DictReader(open(f)) if x["valid"] == "1" and x["vel_scalar"]]
        t = np.array([float(x["t"]) * 64 + 1 for x in r]); h = np.array([float(x["vel_scalar"]) for x in r])
        g = np.arange(int(t.min()) + 1, int(t.max())); H = np.interp(g, t, h); d = np.diff(H)
        # dash window: the peak is the max after the last big rise; search the drop after it
        A = {"E700W": 40, "E700WD": 40, "E700S": 40}.get(n, 0); i0 = int(np.searchsorted(g, A + 2))
        ip = i0 + int(np.argmax(H[i0: len(H) * 3 // 4]))
        if n in ("E386S", "E700S"):
            imin = int(np.argmin(H[20:])) + 20; ip = imin + int(np.argmax(H[imin:imin + 30]))
        E = next((i + 1 for i in range(ip + 3, len(d)) if d[i] < -6), None)
        if E is None: print("%-10s %-6s %s no drop" % (s, n, os.path.basename(f)[:12])); continue
        S = next((i + 1 for i in range(E, len(d)) if d[i] > -4), None)
        if S is None: continue
        pre = H[E - 1]; vz = 796 * (S - E + 1) / 64; hp = np.sqrt(max(H[S] ** 2 - vz ** 2, 0))
        print("%-10s %-6s %-5s %4d %7.1f %7.1f %4d %7.3f %6.1f" % (s[-9:], n, os.path.basename(f).split("_")[0] + os.path.basename(f)[-6:-4], g[E], pre, hp, S - E, hp / pre, pre - hp))

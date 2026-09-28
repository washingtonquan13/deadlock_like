"""adsum.py [NAME...] : per trial of rec_auto/s6_airdash/<NAME>: takeoff (HUD step after the scheduled jump), air-dash
onset (first HUD change after the scheduled dash with z flat), entry h_in = sqrt(HUD^2 - vz^2) with vz pinned
(vz0 416 after a dash jump, 283 plain jump, g 796), peak HUD during the dash (z flat so HUD ~ h), dash end (last tick
the camera z stays within 0.6 u of its dash level), post-dash h = sqrt(HUD^2 - (g*(t-E)/64)^2) at E+6..E+12 (assumes gravity resumes at E)."""
import sys, glob, json, csv, os, numpy as np
MC = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
G = 796.0
names = sys.argv[1:] or ["E200W", "E386W", "E386S", "E386WD", "E520W", "E700W", "E700S", "E700WD"]
print("%-7s %-16s %6s %6s %6s %6s %7s %6s %6s %6s %6s %6s %6s %6s" % ("scen", "trial", "tkoff", "onset", "HUDin", "vz", "h_in", "peak", "pk_t", "end", "h_E+6", "h_E+9", "h_E+12", "HUDmin"))
for n in names:
    sc = json.load(open(os.path.join(MC, "scenarios", "s6_airdash", n + ".json")))
    J = max(e["from"] for e in sc["timeline"] if "jump" in (e.get("buttons") or []))
    A = max(e["from"] for e in sc["timeline"] if "dash" in (e.get("buttons") or []))
    djump = any(e["from"] < J and "dash" in (e.get("buttons") or []) for e in sc["timeline"]) and n.startswith("E700")
    vz0 = 416.0 if djump else 283.0
    for f in sorted(glob.glob(os.path.join(MC, "rec_auto", "s6_airdash", n, "*.csv"))):
        r = [x for x in csv.DictReader(open(f)) if x["valid"] == "1" and x["vel_scalar"] and x["pos_z"]]
        t = np.array([float(x["t"]) * 64 + 1 for x in r]); h = np.array([float(x["vel_scalar"]) for x in r])
        z = np.array([float(x["pos_z"]) for x in r])
        g = np.arange(1, int(t.max())); H = np.interp(g, t, h); Z = np.interp(g, t, z)
        d = np.diff(H)
        # takeoff: largest HUD rise within J..J+8
        k = np.arange(J - 1, J + 8); tk = g[k[np.argmax(d[k])]] + 0.5
        # onset: first tick after A where the HUD departs from its free-fall trend by > 8
        k0 = A - 1; ref = np.polyfit(g[k0 - 4:k0], H[k0 - 4:k0], 1)
        on = next(g[i] for i in range(k0, k0 + 12) if abs(H[i] - np.polyval(ref, g[i])) > 8)
        hud_in = np.polyval(ref, on - 1); vz = vz0 - G * (on - 1 - tk) / 64
        h_in = np.sqrt(max(hud_in ** 2 - vz ** 2, 0))
        win = slice(on - 1, on + 40); ip = np.argmax(H[win]); peak = H[win][ip]; pk_t = g[win][ip] - on
        E = next((g[i] for i in range(on + 10, len(g)) if Z[i] < Z[on + 10:i + 1].max() - 0.3), None)
        hmin = H[E - 1:E + 12].min() if E else float("nan")
        hs = []
        for dt in (6, 9, 12):
            if E is None or E - 1 + dt >= len(H): hs.append(float("nan")); continue
            hu = H[E - 1 + dt]; v = G * dt / 64; hs.append(np.sqrt(max(hu ** 2 - v ** 2, 0)))
        print("%-7s %-16s %6.1f %6d %6.1f %6.0f %7.1f %6.1f %6d %6s %6.1f %6.1f %6.1f %6.1f" % (
            n, os.path.basename(f)[:-4], tk, on, hud_in, vz, h_in, peak, pk_t, E, *hs, hmin))

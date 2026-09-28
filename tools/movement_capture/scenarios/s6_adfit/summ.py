"""summ.py TAG [LAG]: for every s6_airdash E* and old A_* probe: game HUD (trial mean, shifted by LAG ticks) vs sim speed3d
(tools_fit/_out/adfit_TAG_<name>.csv) over the air dash: peak game/sim, sim entry v_par, rms over dash onset..end+10."""
import sys, glob, csv, os, json, numpy as np
MC = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROOT = os.path.abspath(os.path.join(MC, "..", ".."))
tag = sys.argv[1]; LAG = float(sys.argv[2]) if len(sys.argv) > 2 else 2.0
def game(files):
    out = []
    for f in files:
        r = [x for x in csv.DictReader(open(f)) if x["valid"] == "1" and x["vel_scalar"]]
        t = np.array([float(x["t"]) * 64 + 1 for x in r]); h = np.array([float(x["vel_scalar"]) for x in r])
        out.append((t, h))
    return out
cases = []
for j in sorted(glob.glob(os.path.join(MC, "scenarios", "s6_airdash", "E*.json"))):
    n = os.path.basename(j)[:-5]; cases.append((n, sorted(glob.glob(os.path.join(MC, "rec_auto", "s6_airdash", n, "*.csv")))))
for j in sorted(glob.glob(os.path.join(MC, "scenarios", "s6_adfit", "A_*.json"))):
    n = os.path.basename(j)[:-5]; src = json.load(open(j))["record"]["src"]
    d = os.path.dirname(src); p = os.path.basename(src).split("_")[0]
    cases.append((n, sorted(glob.glob(os.path.join(MC, d, p + "_ts*_t[0-9].csv")))))
tot = []
print("%-18s %3s %7s %7s %7s %7s %6s %6s %7s %7s %6s" % ("case", "n", "vpar0", "g_peak", "s_peak", "diff", "rms", "maxab", "g_set", "s_set", "dset"))
for n, files in cases:
    sf = os.path.join(ROOT, "tools_fit", "_out", "adfit_%s_%s.csv" % (tag, n))
    if not os.path.exists(sf) or not files: continue
    s = list(csv.DictReader(open(sf)))
    ad = [i for i, r in enumerate(s) if r["loco"] == "AIR_DASH"]
    if not ad: print(n, "no sim dash"); continue
    a0, a1 = ad[0], ad[-1]
    S = np.array([float(r["speed3d"]) for r in s])
    fw = np.array([float(r["fwd"]) for r in s]); lf = np.array([float(r["left"]) for r in s])
    vpre = np.array([(fw[a0 - 1] - fw[a0 - 2]) * 64, (lf[a0 - 1] - lf[a0 - 2]) * 64])
    vpost = np.array([(fw[a0 + 12] - fw[a0 + 11]) * 64, (lf[a0 + 12] - lf[a0 + 11]) * 64])
    dvec = vpost / (np.linalg.norm(vpost) + 1e-9)
    # dash direction from the sim's own velocity late in the dash (approx: ok for single-key dashes)
    vpar0 = vpre @ dvec
    G = game(files); ks = np.arange(a0, a1 + 11)
    best = None
    for lg in (np.arange(1.0, 3.01, 0.25) if LAG < 0 else [LAG]):
        gm_ = np.nanmean([np.interp(ks + lg, t, h, left=np.nan, right=np.nan) for t, h in G], axis=0)
        r_ = np.sqrt(np.nanmean((gm_ - S[ks]) ** 2))
        if best is None or r_ < best[0]: best = (r_, gm_, lg)
    gm = best[1]
    sm = S[ks]
    # peak: max after the speed minimum inside the dash (handles back dashes)
    kmin = np.argmin(sm[:a1 - a0]); gmin = np.nanargmin(gm[:a1 - a0])
    gp = np.nanmax(gm[gmin:a1 - a0 + 1]); sp = sm[kmin:a1 - a0 + 1].max()
    w = slice(a1 - a0 - 2, a1 - a0 + 11); gset = np.nanmin(gm[w]); sset = np.nanmin(sm[w])
    e = gm - sm; rms = np.sqrt(np.nanmean(e ** 2)); tot.append(e)
    if "side" in n: continue  # hits geometry after the dash (settle 330)
    print("lag%4.2f " % best[2], end=""); print("%-18s %3d %7.0f %7.1f %7.1f %7.1f %6.1f %6.1f %7.1f %7.1f %6.1f" % (n, len(G), vpar0, gp, sp, gp - sp, rms, np.nanmax(abs(e)), gset, sset, gset - sset))
e = np.concatenate(tot); print("ALL rms %.2f" % np.sqrt(np.nanmean(e ** 2)))

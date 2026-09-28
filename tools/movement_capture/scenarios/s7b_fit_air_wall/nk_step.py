"""NK2: horizontal speed near the two apexes, h = sqrt(HUD^2 - vz^2) with vz = G*(t_apex - t) (|vz| < 200 there, so the
vz model matters little). t_apex1 = jump(tick 40 + 3.5 lag) + 300/800; t_apex2 = the HUD-minimum time after the air jump.
Fits log h = a + s*[t > t_aj] - k*(t - t_aj): k free and k fixed 0.2; s = the air-jump step (0 = no takeoff effect).
Usage (from tools/movement_capture): .venv/Scripts/python.exe scenarios/s7b_fit_air_wall/nk_step.py"""
import csv, glob, os
import numpy as np
G = 800.0; LAG = 3.5
tj = (40 - 1 + LAG) / 64; taj = (66 - 1 + LAG) / 64; ta1 = tj + 300 / G
def load(p):
    R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
    return np.array([float(r["t"]) for r in R]), np.array([float(r["vel_scalar"]) for r in R])
allT, allH, allS = [], [], []
for p in sorted(glob.glob("rec_auto/s7_open/NK2/*.csv")):
    t, v = load(p)
    m2 = (t > 1.55) & (t < 1.95); ta2 = t[m2][np.argmin(v[m2])]
    m1 = (t > 0.90) & (t < taj - 0.005)
    rows = []
    for m, ta in ((m1, ta1), (m2, ta2)):
        vz = G * (ta - t[m]); h = np.sqrt(np.clip(v[m] ** 2 - vz ** 2, 1, None)); rows.append((t[m], h))
    T = np.r_[rows[0][0], rows[1][0]]; H = np.r_[rows[0][1], rows[1][1]]; S = (T > taj).astype(float)
    ok = H > 200
    T, H, S = T[ok], H[ok], S[ok]
    c = np.linalg.lstsq(np.c_[np.ones_like(T), S, -(T - taj)], np.log(H), rcond=None)[0]
    c2 = np.linalg.lstsq(np.c_[np.ones_like(T), S], np.log(H) + 0.2 * (T - taj), rcond=None)[0]
    print("%s apex2 t %.3f (vz_aj ~ %.0f) | pre h(t_aj) %.1f | k free: k %.3f step x%.4f | k=0.2: step x%.4f (%+.1f u/s)"
          % (os.path.basename(p)[:-4], ta2, G * (ta2 - taj), np.exp(c2[0]), c[2], np.exp(c[1]), np.exp(c2[1]), np.exp(c2[0]) * (np.exp(c2[1]) - 1)))
    allT.append(T); allH.append(H); allS.append(S)
T = np.concatenate(allT); H = np.concatenate(allH); S = np.concatenate(allS)
c2 = np.linalg.lstsq(np.c_[np.ones_like(T), S], np.log(H) + 0.2 * (T - taj), rcond=None)[0]
r = np.log(H) + 0.2 * (T - taj) - c2[0] - c2[1] * S
print("pooled k=0.2: pre h(t_aj) %.1f  step x%.4f (%+.1f u/s)  rms log resid %.4f  n %d" % (np.exp(c2[0]), np.exp(c2[1]), np.exp(c2[0]) * (np.exp(c2[1]) - 1), r.std(), len(T)))

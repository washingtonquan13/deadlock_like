"""s7b: slide entry threshold. Aligns game HUD (rec_auto/s7_open/SE*) to the sim W ramp-up (lag fit on SEPROBE and the
pre-press part of every trial), then reads the game speed at the crouch-press tick in sim-aligned time.
Usage (from tools/movement_capture): python scenarios/s7b_fit_slide_entry/se_fit.py [TAG]   (TAG = sim csv prefix, default cur)"""
import csv, glob, json, os, sys
import numpy as np
TAG = sys.argv[1] if len(sys.argv) > 1 else "cur"
OUT = "../../tools_fit/_out/s7b_slide_entry"
def game(p):
    R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
    return np.array([float(r["t"]) for r in R]), np.array([float(r["vel_scalar"]) for r in R])
def sim(n):
    R = list(csv.DictReader(open("%s/%s_%s.csv" % (OUT, TAG, n))))
    return np.array([float(r["t"]) for r in R]), np.array([float(r["speed_h"]) for r in R]), [r["loco"] for r in R]
# 1) lag: game HUD(t) vs sim speed at tick = t*64+1+lag, over the W ramp (HUD 60..330)
st, sv, _ = sim("SEPROBE")
lags = np.arange(-2, 8.01, 0.25)
allt = []
for p in sorted(glob.glob("rec_auto/s7_open/*/ts1_t*.csv")):
    n = p.replace("\\", "/").split("/")[-2]
    if not n.startswith("SE"): continue
    sc = json.load(open("scenarios/s7_open/%s.json" % n))
    N = [e["from"] for e in sc["timeline"] if "crouch" in e.get("buttons", [])] or [999]
    N = N[0]
    t, v = game(p)
    m = (v > 60) & (v < 330) & (t * 64 + 1 < N - 1)
    err = [np.sqrt(np.mean((v[m] - np.interp((t[m] * 64 + 1 - L) / 64, st, sv)) ** 2)) for L in lags]
    L = lags[int(np.argmin(err))]
    allt.append(L)
    # sim speed at the last W tick (N-1) is what the crouch sees
    tt, vv, loco = sim(n) if n != "SEPROBE" else (st, sv, None)
    res = ""
    if loco:
        res = "sim %s v[N-1]=%.1f" % ("SLIDE" if "SLIDE" in loco[N:N + 3] else "no-slide", vv[N - 1])
    # game: speed in sim-aligned time at tick N-1 = HUD at recording tick N-1+L; also the peak after the press
    gN1 = np.interp((N - 1 - 1 + L) / 64, t, v)
    pk = np.max(v[(t * 64 + 1 >= N - 1) & (t * 64 + 1 <= N + 8)]) if N < 999 else np.nan
    g25 = np.interp((N - 1) / 64 + 0.25, t, v); g75 = np.interp((N - 1) / 64 + 0.75, t, v)
    slid = "SLIDE" if g25 > 250 else "no-slide"
    s25 = np.interp((N - 1) / 64 + 0.25 - 1 / 64, tt, vv) if loco else np.nan
    s75 = np.interp((N - 1) / 64 + 0.75 - 1 / 64, tt, vv) if loco else np.nan
    print("%-7s %s lag %.2f rms %.1f | game at N-1 (aligned) %.1f peak %.1f -> %s  +.25 %.0f +.75 %.0f | %s  +.25 %.0f +.75 %.0f" % (
        n, os.path.basename(p)[:-4], L, min(err), gN1, pk, slid, g25, g75, res, s25, s75))
print("lag median %.2f ticks" % np.median(allt))

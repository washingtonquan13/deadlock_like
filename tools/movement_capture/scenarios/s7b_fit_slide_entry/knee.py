"""s7b: slide penalty knee for SE340/SE360 (game, 4-tick lag aligned) vs sim. Knee = first aligned tick where the
speed falls > 3 u/s below the linear slide-friction line fitted on the first 0.4 s of the slide; also the
mean decel over the penalty (u/s per tick, speed 300..130). Usage: python .../knee.py [TAG]"""
import csv, glob, json, sys
import numpy as np
TAG = sys.argv[1] if len(sys.argv) > 1 else "cur"; L = 4.0
def knee(k, v, N):
    m = (k >= N + 2) & (k <= N + 26)
    a, b = np.polyfit(k[m], v[m], 1)
    kk = np.arange(N + 2, N + 90, 0.25)
    vv = np.interp(kk, k, v)
    i = np.argmax(vv < a * kk + b - 3)
    ks = kk[(vv < 300) & (vv > 130)]
    dec = (300 - 130) / (ks[-1] - ks[0]) if len(ks) > 1 else np.nan
    return kk[i] - N, -a * 64, dec
for n in ("SE340", "SE360"):
    sc = json.load(open("scenarios/s7_open/%s.json" % n))
    N = [e["from"] for e in sc["timeline"] if "crouch" in e.get("buttons", [])][0]
    for p in sorted(glob.glob("rec_auto/s7_open/%s/ts1_t*.csv" % n)):
        R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
        k = np.array([float(r["t"]) * 64 + 1 - L for r in R]); v = np.array([float(r["vel_scalar"]) for r in R])
        print("%s game %s knee +%.1f ticks, slide decel %.1f u/s^2, penalty decel %.2f u/s/tick" % ((n, p[-6:-4]) + knee(k, v, N)))
    S = list(csv.DictReader(open("../../tools_fit/_out/s7b_slide_entry/%s_%s.csv" % (TAG, n))))
    k = np.array([float(r["tick"]) for r in S]); v = np.array([float(r["speed_h"]) for r in S])
    print("%s sim  %s knee +%.1f ticks, slide decel %.1f u/s^2, penalty decel %.2f u/s/tick" % ((n, TAG) + knee(k, v, N)))

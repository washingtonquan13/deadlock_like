"""Quick per-trial summaries for s7_open. Usage (from tools/movement_capture): python scenarios/s7_open/ana.py KIND NAME...
KIND se: HUD at the crouch press (t=(N-1)/64) and 0.25/0.5/0.75/1.0 s later, plus min HUD / z over the trial (hit check)
KIND hud T1,T2,...: HUD at those game times; KIND air: HUD, z per 2 ticks (for jumps)"""
import csv, glob, json, os, sys
import numpy as np
def load(p):
    R = [r for r in csv.DictReader(open(p)) if r["valid"] == "1"]
    f = lambda k: np.array([float(r[k]) if r[k] else np.nan for r in R])
    return f("t"), f("vel_scalar"), f("pos_z")
def at(t, v, tt):
    return float(np.interp(tt, t, v))
kind = sys.argv[1]; names = sys.argv[2:]
times = None
if kind == "hud":
    times = [float(x) for x in names[0].split(",")]; names = names[1:]
for n in names:
    sc = json.load(open("scenarios/s7_open/%s.json" % n))
    for p in sorted(glob.glob("rec_auto/s7_open/%s/ts1_t*.csv" % n)):
        t, v, z = load(p); tr = os.path.basename(p)[:-4]
        if kind == "se":
            N = [e["from"] for e in sc["timeline"] if "crouch" in e.get("buttons", [])][0]
            t0 = (N - 1) / 64
            s = [at(t, v, t0 + d) for d in (0, 0.25, 0.5, 0.75, 1.0)]
            print("%s %s press@%d HUD %.1f | +.25 %.1f +.5 %.1f +.75 %.1f +1 %.1f | zrange %.1f" % (n, tr, N, *s, np.nanmax(z) - np.nanmin(z)))
        elif kind == "hud":
            print("%s %s " % (n, tr) + " ".join("%.2f:%.1f" % (x, at(t, v, x)) for x in times))

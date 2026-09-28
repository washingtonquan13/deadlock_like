"""RUN (contaminated Haze, plateau ~414 u/s): sim speed_h at 0.4..2.5 s vs the game HUD for a few override sets.
Usage (from tools/movement_capture): python scenarios/s11_conf/run_fit.py "k=v,k=v" ["k=v" ...]"""
import csv, glob, json, os, subprocess, sys
import numpy as np
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
GD = "D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
HERE = os.path.dirname(__file__)
TS = [0.2, 0.3, 0.4, 0.5, 0.6, 0.8, 1.0, 1.5, 2.0]
out = os.path.join(ROOT, "tools_fit", "_out", "s11_run"); os.makedirs(out, exist_ok=True)
G = []
for g in sorted(glob.glob(os.path.join(HERE, "..", "..", "rec_auto", "s11_conf", "RUN", "ts1_t?.csv"))):
    R = [r for r in csv.DictReader(open(g)) if r["valid"] == "1" and r["vel_scalar"] not in ("", "nan")]
    gt = np.array([float(r["t"]) * 64 + 1 - 2.7 for r in R]); v = np.array([float(r["vel_scalar"]) for r in R])
    G.append([np.interp(1 + t * 64, gt, v) for t in TS])
G = np.mean(G, axis=0)
print("%-40s %s" % ("t (s)", " ".join("%5.1f" % t for t in TS)))
print("%-40s %s" % ("game (mean of 3)", " ".join("%5.0f" % q for q in G)))
for i, a in enumerate(sys.argv[1:]):
    fix = {kv.split("=")[0]: float(kv.split("=")[1]) for kv in a.split(",") if kv}
    s = json.load(open(os.path.join(HERE, "RUN.json"))); s["fixed"] = fix
    p = os.path.join(out, "r%d.json" % i); json.dump(s, open(p, "w"), indent=1); c = p[:-5] + ".csv"
    subprocess.run([GD, "--headless", "--path", ROOT, "-s", "res://tools_fit/route_export.gd", "--",
                    "--scenario=" + p.replace("\\", "/"), "--out=" + c.replace("\\", "/")], capture_output=True, check=True)
    R = list(csv.DictReader(open(c)))
    tk = np.array([float(r["tick"]) for r in R]); sh = np.array([float(r["speed_h"]) for r in R])
    v = [np.interp(1 + t * 64, tk, sh) for t in TS]
    print("%-40s %s  rms %.1f" % (a[:40], " ".join("%5.0f" % q for q in v), np.sqrt(np.mean((np.array(v) - G) ** 2))))

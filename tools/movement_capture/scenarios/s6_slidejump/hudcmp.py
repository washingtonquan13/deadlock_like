"""Compare sim speed3d to the game HUD over a tick window, aligning the sim takeoff (first AIR tick after
SIM_FROM) with the game takeoff (first HUD rise > 5 after GAME_FROM). Usage: hudcmp.py SIMCSV SET NAME SIM_FROM GAME_FROM SPAN"""
import sys, os, csv, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from load import load, trials
simf, st, nm, sf, gf, span = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4]), float(sys.argv[5]), float(sys.argv[6])
rows = list(csv.DictReader(open(simf)))
stk = np.array([float(r["tick"]) for r in rows]); s3 = np.array([float(r["speed3d"]) for r in rows]); lo = [r["loco"] for r in rows]
ts = [stk[i] for i in range(1, len(rows)) if stk[i] > sf and lo[i] == "AIR" and lo[i - 1] != "AIR"][0]
for p in trials(st, nm):
    tk, sp, _ = load(p)
    i0 = [i for i in range(1, len(tk)) if tk[i] > gf and sp[i] > sp[i - 1] + 5][0]
    tg = (tk[i0 - 1] + tk[i0]) / 2
    # sim tick k covers (k-1, k]; its value is the state after tick k -> compare at game time tg + (k - ts) + 0.5
    m = (tk > tg) & (tk < tg + span)
    simv = np.interp(tk[m] - tg + ts - 0.5, stk, s3)
    e = simv - sp[m]
    marks = [5, 15, 25, 35, span - 3]
    mk = " ".join("+%d: game %.0f sim %.0f" % (k, np.interp(tg + k, tk, sp), np.interp(ts + k - 0.5, stk, s3)) for k in marks)
    print("%s %s  rms %.1f  mean %+.1f | %s" % (nm, p[-10:-4], np.sqrt(np.mean(e ** 2)), e.mean(), mk))

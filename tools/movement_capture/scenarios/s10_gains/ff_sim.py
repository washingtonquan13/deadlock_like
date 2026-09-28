"""700+ u/s air strafe (FF_*): game vs sim horizontal velocity after a 90 deg air dash, and each keyed run's velocity
minus FF_N's (the strafe gain; the key is square to the motion, so its size tests the 80 vs 50 u/s wishspeed cap).
Usage (from tools/movement_capture): python scenarios/s10_gains/ff_sim.py [--set=...] [--t0= --t1= --dt=] [--lag=ticks]"""
import sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import fa_sim as F
import glob
NAMES = [n for n in ["FF_N", "FF_SA", "FF_WD", "FF_SAE"] if glob.glob("rec_auto/s10_gains/%s/ts1_t?.csv" % n)]
W = np.arange(F.OPT.get("t0", 0.3), F.OPT.get("t1", 1.8) + 1e-9, F.OPT.get("dt", 0.05))
lag = F.OPT.get("lag", 2.7) / 64.0
for n in NAMES: F.gen_run(n)
G = {n: F.game_v(n, W + lag) for n in NAMES}; S = {n: F.sim_v(n, W) for n in NAMES}
print("t (sim time; game shifted by the lag)   |h| game|sim   then per key run: gain vs FF_N game|sim (u/s)")
for i, a in enumerate(W):
    row = "  %.2f  %4.0f|%4.0f" % (a, np.hypot(*G["FF_N"][i]), np.hypot(*S["FF_N"][i]))
    for n in NAMES[1:]:
        row += "   %s %4.0f|%4.0f  |h| %4.0f|%4.0f" % (n[3:], np.hypot(*(G[n][i] - G["FF_N"][i])), np.hypot(*(S[n][i] - S["FF_N"][i])),
                                               np.hypot(*G[n][i]), np.hypot(*S[n][i]))
    print(row)

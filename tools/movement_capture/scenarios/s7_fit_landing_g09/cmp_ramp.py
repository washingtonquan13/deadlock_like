"""Game HUD (median of trials) vs sim speed3d on the ramp1 replica: cmp_ramp.py NAME [variant ...] (run from project root)."""
import sys, csv, glob, statistics as st
name = sys.argv[1]; vars_ = sys.argv[2:] or [""]
game = {}
for p in glob.glob(f"tools/movement_capture/rec_auto/s7_ramp/{name}/*ts1_t*.csv"):
    for r in csv.DictReader(open(p)):
        if r["valid"] == "1" and r["vel_scalar"]:
            k = round(float(r["t"]) * 64 + 1)
            if k >= 0: game.setdefault(k, []).append(float(r["vel_scalar"]))
sims = [{int(r["tick"]): r for r in csv.DictReader(open(f"tools_fit/_out/s7_landing_g09/ramp_{name}{v}.csv"))} for v in vars_]
print("tick  game  " + "  ".join("sim%s" % v for v in vars_))
for k in range(0, max(sims[0]) + 1, 8):
    g = [game[j] for j in range(k - 1, k + 2) if j in game]
    gv = st.median(sum(g, [])) if g else float("nan")
    print("%4d %6.0f  " % (k, gv) + "  ".join("%6s %-6s" % (s[k]["speed3d"], s[k]["loco"][:6]) if k in s else "" for s in sims))

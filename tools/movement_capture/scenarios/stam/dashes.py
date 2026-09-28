"""Count ground dashes that fired: HUD speed reaching >= 600 within 12 ticks after each dash press. Usage: dashes.py CSV T1 T2 ..."""
import csv, sys
R = [(float(r["t"]) * 64 + 1, float(r["vel_scalar"])) for r in csv.DictReader(open(sys.argv[1])) if r["valid"] == "1" and r["vel_scalar"]]
for t0 in map(int, sys.argv[2:]):
    w = [v for t, v in R if t0 <= t <= t0 + 12]
    print("press %d: max %.0f -> %s" % (t0, max(w) if w else -1, "DASH" if w and max(w) >= 600 else "no"))

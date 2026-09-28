"""Crouch-after-landing timing: jump rise (sample time), landing, the tick braking stops (slide start), slide speed.
Usage: cslide.py CSV..."""
import csv, sys
for p in sys.argv[1:]:
    R = [(float(r["t"]) * 64 + 1, float(r["vel_scalar"]), float(r["pos_z"])) for r in csv.DictReader(open(p))
         if r["valid"] == "1" and r["vel_scalar"]]
    z0 = R[0][2]
    rise = next(t for t, v, z in R if z - z0 > 0.5)
    top = max(range(len(R)), key=lambda i: R[i][2])
    land = next(i for i in range(top, len(R)) if R[i][1] < R[i - 1][1] - 20)
    # slide start: first sample after landing whose speed drop to the next sample is < 3 u/s (braking is ~15 per sample)
    k = next(i for i in range(land + 1, len(R) - 2) if R[i][1] - R[i + 2][1] < 4)
    print("%-34s rise %.1f  land %.1f  slide %.1f at %.0f  (land->slide %.1f)" % (p, rise, R[land][0], R[k][0], R[k][1], R[k][0] - R[land][0]))

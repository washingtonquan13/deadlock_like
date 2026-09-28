"""Sim traces (route_export csv): second takeoff h (last GROUND tick h before the hop), flight ticks, h at the
last air tick of the second flight, and the first ground h after it. Also first-landing values for LT runs."""
import sys, csv
for p in sys.argv[1:]:
    R=list(csv.DictReader(open(p)))
    loc=[r["loco"] for r in R]; h=[float(r["speed_h"]) for r in R]
    # air segments
    segs=[]; i=0
    while i<len(R):
        if loc[i]=="AIR":
            j=i
            while j<len(R) and loc[j]=="AIR": j+=1
            segs.append((i,j)); i=j
        else: i+=1
    out=[]
    for a,b in segs:
        out.append("air %d..%d (T %d) h_before %.1f h_first_air %.1f h_last_air %.1f h_after %.1f"%(a,b-1,b-a,h[a-1],h[a],h[b-1],h[b] if b<len(R) else -1))
    print(p.split("/")[-1]); [print("  ",o) for o in out]

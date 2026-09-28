"""Verifier: landing location along the street_y148 runway (camera displacement from start) vs landing ratio."""
import csv,sys,glob,os,numpy as np
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from landonly_lib import run
def pos(p):
    P=[];T=[]
    for r in csv.DictReader(open(p)):
        if r['valid']!='1': continue
        T.append(float(r['t'])*64+1); P.append([float(r['pos_x']),float(r['pos_y']),float(r['pos_z'])])
    return np.array(T),np.array(P)
for d in sys.argv[1:]:
    for p in sorted(glob.glob(d+'/*.csv')):
        T,P=pos(p); p0=P[0]
        for (ta,tl,hm,hl,post,r,sl) in run(p):
            if hm<50: continue
            i=np.argmin(abs(T-tl)); dist=np.hypot(*(P[i,:2]-p0[:2]))
            # camera z 20 ticks after landing vs start z
            j=np.argmin(abs(T-(tl+25))); 
            print(f"{d.split('rec_auto/')[-1]:18s} {os.path.basename(p)[:6]} land@{tl:6.1f} hland={hl:6.1f} ratio={r:.3f} slope={sl:6.2f} dist={dist:6.0f} dz(+25)={P[j,2]-p0[2]:6.1f}")

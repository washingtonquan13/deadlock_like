"""Within-flight penalty shape: h(t)=sqrt(HUD^2 - vz^2), vz from the fitted apex (hop.py, G=796);
normalized by h0 e^{-0.2 dt}. Averaged over trials in 2-tick bins after takeoff."""
import sys, os, glob
sys.path.insert(0, os.path.dirname(__file__)); sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "s6_slidejump"))
from hop import analyse, D, G
from load import load
import numpy as np
for st,nm in [("s6_slidejump","SHH6"),("s7_open","SHH12"),("s7_open","SHH20"),("s7_open","SHH30"),("s6_slidejump","SHH40")]:
    bins={}
    for p in sorted(glob.glob(os.path.join(os.path.dirname(__file__),"..","..","rec_auto",st,nm,"*.csv"))):
        r=analyse(p,40); tk,sp,_=load(p)
        m=(tk>r['t0'])&(tk<r['t2']-0.5)
        for t,s in zip(tk[m],sp[m]):
            vz=G*(r['ta']-t)/64; h=np.sqrt(max(s*s-vz*vz,0))
            k=int((t-r['t0'])//2)*2; bins.setdefault(k,[]).append(h/(r['h0']*np.exp(-D*(t-r['t0'])/64)))
    print(nm," ".join("%d:%.3f"%(k,np.mean(v)) for k,v in sorted(bins.items())))

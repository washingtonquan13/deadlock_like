"""Independent landing fit: fit the whole descent from before the HUD minimum to landing with
HUD^2 = (h0 e^{-D (t-tc)})^2 + (G (t-ta)/64)^2, free h0, ta (apex tick), optional free G.
Landing tick t1 = midpoint of the last sample before the first big HUD drop and the previous one.
Post = linear ground trend over t1+1.5..t1+8 back-extrapolated to t1."""
import sys, os, glob
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "s6_slidejump"))
from load import load
import numpy as np
D=0.2
def fit(path, J, t_from_min=-8, freeG=False):
    tk,sp,pos=load(path)
    i1=None
    for i in range(3,len(tk)):
        if tk[i]<J: continue
        if sp[i]<sp[i-1]-6 and sp[i-1]>sp[i-3]: i1=i;break
    t1=tk[i1-1]+0.5*(tk[i1]-tk[i1-1])
    # HUD minimum in the flight before landing
    w=(tk>t1-50)&(tk<t1-1)
    imin=np.argmin(np.where(w,sp,1e9)); tmin=tk[imin]
    m=(tk>tmin+t_from_min)&(tk<t1-1.0)
    best=None
    Gs=np.arange(700,900,4) if freeG else [796.0]
    for G in Gs:
      for ta in np.arange(tmin-20,tmin+5,0.1):
        e=np.exp(-2*D*(tk[m]-t1)/64); vz=G*(tk[m]-ta)/64
        y=sp[m]**2-vz**2; h2=np.sum(y*e)/np.sum(e*e)
        if h2<=0: continue
        f=np.sqrt(h2*e+vz*vz)-sp[m]; rr=np.sum(f*f)
        if best is None or rr<best[0]: best=(rr,np.sqrt(h2),ta,G,f)
    class R: pass
    r=R(); r.x=[best[1],best[2],best[3]]; r.fun=best[4]
    G=best[3]
    post=(tk>t1+1.5)&(tk<t1+8)
    c=np.polyfit(tk[post],sp[post],1); vp=np.polyval(c,t1)
    rms=np.sqrt(np.mean(r.fun**2))
    return t1,r.x[0],r.x[1],G,rms,vp,-G*(t1-r.x[1])/64
if __name__=="__main__":
    freeG="--G" in sys.argv
    args=[a for a in sys.argv[1:] if a!="--G"]
    for i in range(0,len(args),3):
        st,nm,J=args[i],args[i+1],float(args[i+2])
        for p in sorted(glob.glob(os.path.join(os.path.dirname(__file__),"..","..","rec_auto",st,nm,"*.csv"))):
            t1,h,ta,G,rms,vp,vzl=fit(p,J,freeG=freeG)
            print("%-6s %-9s land %6.1f apex %6.1f G %5.0f vzl %5.0f h_land %6.1f rms %4.1f post %6.1f ratio %.3f"%(nm,os.path.basename(p)[:-4],t1,ta,G,vzl,h,rms,vp,vp/h))

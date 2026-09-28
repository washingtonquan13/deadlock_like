"""Second flight of a chained slide hop, independent of the analyst's fit.
t0 = takeoff (first HUD rise > 20 after the first landing), h0 = ground HUD trend over t0-8..t0-1 extrapolated to t0.
Descent fit (HUD^2 = h^2 e^{-2D..} + vz^2, free h, apex, G=796) over [fit_from, landing-1] with drag 0.2;
factor = h(t) / (h0 e^{-0.2 (t-t0)/64}) evaluated at the landing (so it holds only once the penalty is spent)."""
import sys, os, glob
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "s6_slidejump"))
from load import load
import numpy as np
D=0.2; G=796.0
def first_landing(tk,sp,J):
    for i in range(3,len(tk)):
        if tk[i]>=J and sp[i]<sp[i-1]-6 and sp[i-1]>sp[i-3]: return i
def analyse(path,J,start_after_apex=0.0):
    tk,sp,pos=load(path)
    i1=first_landing(tk,sp,J)
    # takeoff: first rise > 20 after the ground segment
    i=i1+4
    while not (sp[i]>sp[i-1]+20): i+=1
    t0=tk[i-1]+0.5*(tk[i]-tk[i-1])
    tl_prev=tk[i1-1]+0.5*(tk[i1]-tk[i1-1])
    g=(tk>max(t0-9,tl_prev+1.3))&(tk<t0-0.8)
    c=np.polyfit(tk[g],sp[g],1); h0=np.polyval(c,t0)
    i2=first_landing(tk,sp,t0+15)
    t2=tk[i2-1]+0.5*(tk[i2]-tk[i2-1])
    w=(tk>t0+3)&(tk<t2-1); imin=np.argmin(np.where(w,sp,1e9)); tmin=tk[imin]
    m=(tk>tmin+start_after_apex)&(tk<t2-1.0)
    best=None
    for ta in np.arange(t0+5,t2-5,0.1):
        e=np.exp(-2*D*(tk[m]-t2)/64); vz=G*(tk[m]-ta)/64
        y=sp[m]**2-vz**2; h2=np.sum(y*e)/np.sum(e*e)
        if h2<=0: continue
        f=np.sqrt(h2*e+vz*vz)-sp[m]; rr=np.mean(f*f)
        if best is None or rr<best[0]: best=(rr,np.sqrt(h2),ta)
    rr,h2l,ta=best
    fac=h2l/(h0*np.exp(-D*(t2-t0)/64))
    return dict(tl1=tl_prev,t0=t0,delay=t0-tl_prev,h0=h0,tmin=tmin,hmin=sp[imin],ta=ta,t2=t2,T=t2-t0,
                vz0=G*(ta-t0)/64,vzl=-G*(t2-ta)/64,hland=h2l,rms=np.sqrt(rr),fac=fac,apexfac=sp[imin]/(h0*np.exp(-D*(tmin-t0)/64)))
if __name__=="__main__":
    a=sys.argv[1:]; saa=0.0
    if a and a[0].startswith("--after="): saa=float(a[0][8:]); a=a[1:]
    for k in range(0,len(a),3):
        st,nm,J=a[k],a[k+1],float(a[k+2])
        for p in sorted(glob.glob(os.path.join(os.path.dirname(__file__),"..","..","rec_auto",st,nm,"*.csv"))):
            r=analyse(p,J,saa)
            print("%-6s %s land1 %5.1f t0 %5.1f dly %4.1f h0 %5.1f | apex(HUDmin) %5.1f %5.1f af %.3f | T %4.1f vz0 %4.0f vzl %4.0f h_land %5.1f rms %.1f FACTOR %.3f"%(
                nm,os.path.basename(p)[:-4],r['tl1'],r['t0'],r['delay'],r['h0'],r['tmin'],r['hmin'],r['apexfac'],r['T'],r['vz0'],r['vzl'],r['hland'],r['rms'],r['fac']))

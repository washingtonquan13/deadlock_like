# Independent verifier: slide-friction line fit after press, knee = first tick >=3 u/s below the line (and >=6 below 2 ticks later).
import sys, glob, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from v_lag import *
def knee(x, v, press, thr=3.0):
    m=(x>=press+3)&(x<=press+25)
    a,b=np.polyfit(x[m],v[m],1)
    res=v-(a*x+b)
    for i in range(len(x)):
        if x[i]>press+26 and res[i]<-thr:
            # interpolate crossing
            j=i-1; xc = x[j]+(x[i]-x[j])*((-thr)-res[j])/(res[i]-res[j])
            return xc-press, -a*64
    return None, -a*64
for n in sys.argv[1:]:
    sc=f'scenarios/s7_open/{n}.json'; N=lastW(sc); press=N+1
    ks,vs,_=load_sim(f'{ROOT}/tools_fit/_out/s7b_verify/{n}.csv')
    k,s=knee(ks,vs,press); print(f'{n} SIM knee=+{k:.1f} ticks slope={s:.1f} u/s^2')
    for p in sorted(glob.glob(f'rec_auto/s7_open/{n}/*_t?.csv')):
        tg,vg=load_game(p); (L,r),_=fit_lag(tg,vg,ks,vs,N)
        x=tg*64+1-L
        k,s=knee(x,vg,press)
        # also post-knee decel and time to zero
        z = x[(x>press+30)&(vg<1)]
        zs = ks[(ks>press+30)&(vs<1)]
        print(f'  {os.path.basename(p)} lag={L:.2f} knee=+{k:.1f} slope={s:.1f} zero_game=+{(z[0]-press)/64 if len(z) else float("nan"):.3f}s zero_sim=+{(zs[0]-press)/64 if len(zs) else float("nan"):.3f}s')
        for d in (40,45,48,55):
            print(f'     +{d}: game {np.interp(press+d,x,vg):.1f} sim {np.interp(press+d,ks,vs):.1f}')

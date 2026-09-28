# Landing-slide onset measured HUD-to-HUD (lag cancels): touchdown = HUD 3D->2D drop; knee = 3 u/s below the pre-knee line.
import sys, glob, os, csv, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from v_lag import load_game, load_sim, ROOT
def knee_after(x, v, a0, b0):
    m=(x>=a0)&(x<=b0); a,b=np.polyfit(x[m],v[m],1); res=v-(a*x+b)
    for i in range(1,len(x)):
        if x[i]>b0 and res[i]<-3:
            j=i-1; return x[j]+(x[i]-x[j])*((-3)-res[j])/(res[i]-res[j])
for n in sys.argv[1:]:
    ks,vs,lo=load_sim(f'{ROOT}/tools_fit/_out/s7b_verify/{n}.csv')
    # sim touchdown: first tick after air where loco not AIR
    air=[i for i,l in enumerate(lo) if 'AIR' in l]; td=air[-1]+1 if air else None
    # choose last air segment's end
    segs=[i for i in range(1,len(lo)) if 'AIR' in lo[i-1] and 'AIR' not in lo[i]]
    td=segs[-1]
    k=knee_after(ks,vs,td+3,td+25)
    print(f'{n} SIM touchdown {td} ({lo[td]}) knee {k} gap {(k-td) if k else None}')
    for p in sorted(glob.glob(f'rec_auto/lslide/{n}/*_t?.csv')):
        tg,vg=load_game(p); x=tg*64+1
        d=np.diff(vg); i=int(np.argmax(-d*(x[1:]>60)))  # biggest drop = touchdown
        tdg=(x[i]+x[i+1])/2
        k=knee_after(x,vg,tdg+3,tdg+25)
        print(f'  {os.path.basename(p)} HUD touchdown {tdg:.1f} knee {k:.1f} gap {k-tdg:.1f}')

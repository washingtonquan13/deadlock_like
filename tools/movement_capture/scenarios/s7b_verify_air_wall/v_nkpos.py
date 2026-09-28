# position-only check of the NK2 air-jump horizontal step (independent of HUD)
import csv,glob,math,numpy as np
k=0.2
def load(p):
    R=[r for r in csv.DictReader(open(p)) if r['valid']=='1']
    a=np.array([[float(r['t'])*64+1,float(r['t']),float(r['pos_x']),float(r['pos_y'])] for r in R]); return a
for p in sorted(glob.glob('rec_auto/s7_open/NK2/*_t?.csv')):
    a=load(p); tk=a[:,0]
    # direction of travel from tk45..130
    m=(tk>=45)&(tk<=130); d=a[m][-1,2:4]-a[m][0,2:4]; d/=np.linalg.norm(d)
    s=a[:,2:4]@d; n=a[:,2:4]@np.array([-d[1],d[0]])
    res={}
    for lab,(lo,hi) in {'pre':(46,65),'post':(68,130)}.items():
        m=(tk>=lo)&(tk<=hi); t=a[m,1]-(66-1)/64
        X=np.c_[np.ones(m.sum()),(1-np.exp(-k*t))/k]   # s = s0 + v66*(1-e^-kt)/k
        c,*_=np.linalg.lstsq(X,s[m],rcond=None); r=s[m]-X@c
        res[lab]=(c[1],r.std())
    print(p[-10:],' v@66 pre %.1f (rms %.2f)  post %.1f (rms %.2f)  step %+.1f  lateral drift %.1f'%(res['pre'][0],res['pre'][1],res['post'][0],res['post'][1],res['post'][0]-res['pre'][0], np.ptp(n[(tk>=45)&(tk<=130)])))

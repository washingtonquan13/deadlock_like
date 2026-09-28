import numpy as np
SEG={1:[(1.05,1.8)],2:[(1.55,2.35)],3:[(1.0,2.0)],4:[(1.15,1.65),(3.35,3.95)]}
for i,segs in SEG.items():
    a=np.genfromtxt(f'v{i}.csv',delimiter=',',names=True)
    P=np.c_[a['x'],a['y'],a['z']]; t=a['frame']/60
    keep=np.r_[True,np.abs(np.diff(P,axis=0)).max(1)>0]   # drop duplicate frames
    for t0,t1 in segs:
        m=keep&(t>=t0)&(t<=t1); Q=P[m]; tt=t[m]; v=a['vel'][m]
        s=np.r_[0,np.cumsum(np.hypot(*np.diff(Q[:,:2],axis=0).T))]
        k=-np.polyfit(s,Q[:,2],1)[0]; th=np.degrees(np.arctan(k))
        acc=np.polyfit(tt,v,1)[0]
        d=Q[-1,:2]-Q[0,:2]; head=np.degrees(np.arctan2(d[1],d[0]))
        print(f'v{i} {t0}-{t1}: slope {th:5.1f} deg (tan {k:.3f}), g*tan={800*k:5.0f}, HUD accel {acc:5.0f} u/s^2, ratio {acc/(800*k):.2f}, v {v[0]:.0f}->{v[-1]:.0f}, heading {head:.0f}')

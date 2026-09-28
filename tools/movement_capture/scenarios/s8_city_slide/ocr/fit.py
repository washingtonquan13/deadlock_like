import numpy as np
SEG={1:[(1.05,1.8)],2:[(1.55,2.35)],3:[(1.0,2.0)],4:[(1.2,1.65),(3.4,3.95)]}
X=[];Y=[]
for i,segs in SEG.items():
    a=np.genfromtxt(f'v{i}.csv',delimiter=',',names=True)
    P=np.c_[a['x'],a['y'],a['z']]; t=a['frame']/60; v=a['vel']
    keep=np.r_[True,np.abs(np.diff(P,axis=0)).max(1)>0]
    P,t,v=P[keep],t[keep],v[keep]
    s=np.r_[0,np.cumsum(np.hypot(*np.diff(P[:,:2],axis=0).T))]
    for t0,t1 in segs:
        w=0.2
        for tc in np.arange(t0+w/2,t1-w/2+1e-9,0.05):
            m=(t>=tc-w/2)&(t<=tc+w/2)
            acc=np.polyfit(t[m],v[m],1)[0]; k=-np.polyfit(s[m],P[m,2],1)[0]
            X.append((800*k,np.interp(tc,t,v),i)); Y.append(acc)
X=np.array(X);Y=np.array(Y)
for row,y in zip(X,Y): print(f'v{int(row[2])} gtan {row[0]:5.0f} v {row[1]:5.0f} acc {y:5.0f}')
M=np.c_[X[:,0],-X[:,1]]
c,*_=np.linalg.lstsq(M,Y,rcond=None); print('a = %.3f*g*tan - %.3f*v'%tuple(c), 'rms',np.sqrt(np.mean((M@c-Y)**2)))
M=np.c_[X[:,0],-X[:,1],np.ones(len(X))]
c,*_=np.linalg.lstsq(M,Y,rcond=None); print('with const',c, 'rms',np.sqrt(np.mean((M@c-Y)**2)))
c=np.linalg.lstsq(X[:,:1],Y,rcond=None)[0]; print('pure',c,'rms',np.sqrt(np.mean((X[:,:1]@c-Y)**2)))
# along-slope: h accel = g sin cos - D v
th=np.arctan(X[:,0]/800); M=np.c_[800*np.sin(th)*np.cos(th),-X[:,1]]
c,*_=np.linalg.lstsq(M,Y,rcond=None); print('sincos',c,'rms',np.sqrt(np.mean((M@c-Y)**2)))

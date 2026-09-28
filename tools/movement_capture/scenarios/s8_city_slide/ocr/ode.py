import numpy as np
# slope segments (t0,t1) where the player is on the ramp and sliding
SEG={1:(1.05,1.80),2:(1.75,2.40),3:(0.85,2.05),4:(3.40,3.95)}
data={}
for i,(t0,t1) in SEG.items():
    a=np.genfromtxt(f'v{i}.csv',delimiter=',',names=True)
    P=np.c_[a['x'],a['y'],a['z']]; t=a['frame']/60; v=a['vel']
    keep=np.r_[True,np.abs(np.diff(P,axis=0)).max(1)>0]
    P,t,v=P[keep],t[keep],v[keep]
    s=np.r_[0,np.cumsum(np.hypot(*np.diff(P[:,:2],axis=0).T))]
    m=(t>=t0)&(t<=t1)
    tan=-np.polyfit(s[m],P[m,2],1)[0]
    data[i]=(t[m],v[m],tan)
    print(i,'angle %.1f'%np.degrees(np.arctan(tan)), 'v %.0f -> %.0f over %.2f s'%(v[m][0],v[m][-1],t[m][-1]-t[m][0]))
def sim(k,f,mode,t,v,tan):
    dt=1/64; vv=v[0]; tt=t[0]; out=[]
    th=np.arctan(tan)
    A=800*(tan if mode=='tan' else np.sin(th)*np.cos(th) if mode=='sc' else np.sin(th))
    for T in t:
        while tt<T-1e-9: vv+= (k*A - f*vv)*dt; tt+=dt
        out.append(vv)
    return np.array(out)
for mode in ('tan','sc','sin'):
  best=None
  for k in np.arange(0.5,1.31,0.01):
    for f in np.arange(0,0.61,0.01):
      e=np.concatenate([sim(k,f,mode,*data[i])-data[i][1] for i in (1,2,3)])
      r=np.sqrt(np.mean(e**2))
      if best is None or r<best[0]: best=(r,k,f)
  print(mode,'best rms %.1f k %.2f f %.2f'%best)
  for f in (0,0.19):
    b=min((np.sqrt(np.mean(np.concatenate([sim(k,f,mode,*data[i])-data[i][1] for i in (1,2,3)])**2)),k) for k in np.arange(0.5,1.31,0.01))
    print('   f=%.2f  rms %.1f k %.2f'%(f,*b))
  r,k,f=best
  for i in (1,2,3,4):
    e=sim(k,f,mode,*data[i])-data[i][1]; print('   v%d rms %.1f end err %.0f'%(i,np.sqrt(np.mean(e**2)),e[-1]))

# Lag-aware wall-jump decomposition from camera positions (no HUD). Kick time = first frame with vz > 150 u/s.
# pre: lateral slope over the 2.2 ticks before the kick; post: drag-corrected lateral fit over kick+1 .. kick+29.
import csv,glob,math,sys,numpy as np
k=0.2
def load(p):
    R=[r for r in csv.DictReader(open(p)) if r['valid']=='1' and r['pos_x']!='' and r['ang_yaw']!='']
    return np.array([[float(r['t'])*64+1,float(r['t']),float(r['pos_x']),float(r['pos_y']),float(r['pos_z']),float(r['ang_yaw'])] for r in R])
P=[];Q=[]
for sub in sys.argv[1:]:
  for p in sorted(glob.glob(f'rec_auto/{sub}/*_t?.csv')):
    a=load(p); tk=a[:,0]
    yaw=math.radians(np.median(a[(tk>60)&(tk<130),5]))
    f=np.array([math.cos(yaw),math.sin(yaw)]); r=np.array([math.sin(yaw),-math.cos(yaw)])
    fw=a[:,2:4]@f; la=a[:,2:4]@r; z=a[:,4]
    vz=np.gradient(z,a[:,1])
    i=np.where((tk>86)&(vz>150))[0]
    if len(i)==0: print(p,'no kick'); continue
    tkick=tk[i[0]-1]  # last frame before rising
    def fit(sig,lo,hi,drag,t0):
        m=(tk>=lo)&(tk<=hi); t=a[m,1]-(t0-1)/64
        X=np.c_[np.ones(m.sum()),(1-np.exp(-k*t))/k if drag else t]
        c,*_=np.linalg.lstsq(X,sig[m],rcond=None); return c[1]
    pre=fit(la,tkick-2.2,tkick,False,tkick); prez=fit(z,tkick-2.2,tkick,False,tkick)
    post=fit(la,tkick+1,tkick+29,True,tkick+0.5); nrm=fit(fw,tkick+1,tkick+29,True,tkick+0.5)
    print('%-18s kick@%.1f  pre_lat %6.1f pre_vz %6.1f | post_lat %6.1f normal %6.1f | post-0.95pre %6.1f'%(sub+p[-6:-4],tkick,pre,prez,post,nrm,post-0.95*pre))
    if 'WJD' in sub or 'WJA' in sub: s=1 if post>0 else -1; P.append(pre*s); Q.append(post*s)
P=np.array(P);Q=np.array(Q)
if len(P)>2:
  for keep in (0,0.95,1.0): d=Q-keep*P; print('keep %.2f: kick %.1f sd %.1f'%(keep,d.mean(),d.std(ddof=1)))
  print('slope post vs pre', np.polyfit(P,Q,1), 'corr',np.corrcoef(P,Q)[0,1], 'n',len(P))

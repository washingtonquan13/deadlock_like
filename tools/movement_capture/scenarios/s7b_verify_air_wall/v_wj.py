# Own wall-jump decomposition from camera positions. Frame: view yaw (wallA is faced head-on, ~world aligned).
# lat = +right of view. Pre = lateral velocity over ticks 84..88 (linear fit), post = drag-corrected launch fit 89..118.
import csv,glob,math,sys,numpy as np
k=0.2
def load(p):
    R=[r for r in csv.DictReader(open(p)) if r['valid']=='1']
    return np.array([[float(r['t'])*64+1,float(r['t']),float(r['pos_x']),float(r['pos_y']),float(r['pos_z']),float(r['ang_yaw']),float(r['vel_scalar'])] for r in R])
rows=[]
for sub in sys.argv[1:]:
  for p in sorted(glob.glob(f'rec_auto/{sub}/*_t?.csv')):
    a=load(p); tk=a[:,0]
    yaw=math.radians(a[(tk>60)&(tk<130),5].mean()); ys=np.ptp(a[(tk>60)&(tk<130),5])
    f=np.array([math.cos(yaw),math.sin(yaw)]); r=np.array([math.sin(yaw),-math.cos(yaw)])
    fw=a[:,2:4]@f; la=a[:,2:4]@r
    def vel(sig,lo,hi,t0,drag):
        m=(tk>=lo)&(tk<=hi); t=a[m,1]-(t0-1)/64
        X=np.c_[np.ones(m.sum()),(1-np.exp(-k*t))/k if drag else t]
        c,*_=np.linalg.lstsq(X,sig[m],rcond=None); return c[1],m.sum()
    pre,npre=vel(la,83,88.5,88,False)
    pre2,_=vel(la,80,88.5,88,False)  # includes pre-key ticks, sanity
    post,npost=vel(la,89.5,118,88.5,True)
    postS,_=vel(la,89.5,100,88.5,False)
    nrm,_=vel(fw,89.5,118,88.5,True)
    lat83=la[(tk>=78)&(tk<=84)]
    print('%-22s yawspread %.2f pre %6.1f (n%d)  post %6.1f  post_short %6.1f  normal %7.1f  post-0.95pre %6.1f'%(sub+'/'+p[-6:-4],ys,pre,npre,post,postS,nrm,post-0.95*pre))
    rows.append((sub,pre,post))
    if '-v' in sys.argv[0:0]: pass

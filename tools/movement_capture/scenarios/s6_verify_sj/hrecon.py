"""Verifier: h(t)=sqrt(HUD^2 - vz^2), vz pinned: vz=g*(tmid-t)/64, tmid from HUD edge midpoints (display offset cancels)."""
import csv,sys,numpy as np
G=796.0
def load(p):
    T=[];S=[]
    for r in csv.DictReader(open(p)):
        if r['valid']!='1' or r['vel_scalar']=='': continue
        T.append(float(r['t'])*64+1); S.append(float(r['vel_scalar']))
    return np.array(T),np.array(S)
def cross(T,S,a,b,lvl):
    for i in range(len(T)-1):
        if a<=T[i]<=b and (S[i]-lvl)*(S[i+1]-lvl)<=0 and S[i]!=S[i+1]:
            return T[i]+(lvl-S[i])/(S[i+1]-S[i])*(T[i+1]-T[i])
p,a,b=sys.argv[1],float(sys.argv[2]),float(sys.argv[3])  # window around the hop
T,S=load(p); m=(T>=a)&(T<=b); t=T[m]; s=S[m]
d=np.diff(s); i=np.argmax(d); k=np.argmin(d)
t_up=cross(t,s,t[i]-1,t[i+1]+1,(s[i]+s[i+1])/2); t_dn=cross(t,s,t[k]-1,t[k+1]+1,(s[k]+s[k+1])/2)
# use pre-rise ground and top-of-spike as the edge levels
pre=s[max(0,i-1)]; top=s[i+1:i+4].max(); t_up=cross(t,s,t[i]-2,t[i]+4,(pre+top)/2)
last=s[k]; post=s[k+3]; t_dn=cross(t,s,t[k]-2,t[k]+4,(last+post)/2)
tm=(t_up+t_dn)/2; T_air=t_dn-t_up
print(f"takeoff~{t_up:.2f} land~{t_dn:.2f} air={T_air:.2f}tk vz0={G*T_air/128:.1f} ground_pre={pre:.1f}")
for off in (-1.0,0.0,1.0):
  vals=[]
  for tt,ss in zip(t,s):
    if t_up+2<tt<t_dn-2:
        vz=G*(tm+off-tt)/64; h2=ss*ss-vz*vz
        vals.append((tt-t_up,np.sqrt(h2) if h2>0 else np.nan))
  v=np.array(vals)
  # print h at a few times and local drag rate
  out=[]
  for tq in (3,5,8,12,16,20,25,30,35,40):
      w=np.abs(v[:,0]-tq)<1.2
      if w.any(): out.append(f"{tq}:{np.nanmean(v[w,1]):.0f}")
  # drag rates between segments
  def rate(a1,a2):
      w1=np.abs(v[:,0]-a1)<1.5; w2=np.abs(v[:,0]-a2)<1.5
      return np.log(np.nanmean(v[w1,1])/np.nanmean(v[w2,1]))/((a2-a1)/64)
  print(f" tmid{off:+.0f}: h@ "+" ".join(out)+f" | rate 4-12={rate(4,12):.2f} 12-22={rate(12,22):.2f} 22-40={rate(22,40):.2f}")

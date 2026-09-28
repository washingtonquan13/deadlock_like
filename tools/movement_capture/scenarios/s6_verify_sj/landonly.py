"""Verifier: every landing (big HUD drop after a rising air branch). h at HUD-min (apex) -> drag 0.2 -> landing; vs ground HUD back-extrapolated."""
import csv,sys,glob,os,numpy as np
G=796.0; D=0.2
def load(p):
    T=[];S=[]
    for r in csv.DictReader(open(p)):
        if r['valid']!='1' or r['vel_scalar']=='': continue
        T.append(float(r['t'])*64+1); S.append(float(r['vel_scalar']))
    return np.array(T),np.array(S)
def landings(T,S,tmin=20):
    out=[]
    for k in range(3,len(S)-3):
        if T[k]<tmin: continue
        if S[k+1]-S[k]<-12 and S[k]>S[k-1]+1 and S[k-1]>S[k-2]:
            j=k
            while j>0 and S[j-1]<=S[j]+0.3: j-=1
            if T[k]-T[j]<8: continue
            out.append((j,k))
    return out
def run(p):
    T,S=load(p); res=[]
    for j,k in landings(T,S):
        tl=T[k]+0.5; hm=S[j]; vz=-D*hm*hm/G; h=np.sqrt(hm*hm-vz*vz)
        hl=h*np.exp(-D*(tl-T[j])/64)
        m=(T>tl+1.5)&(T<tl+10)
        if m.sum()<3: continue
        c=np.polyfit(T[m],S[m],1); post=np.polyval(c,tl)
        res.append((T[j],tl,hm,hl,post,post/hl,c[0]))
    return res
for d in sys.argv[1:]:
    for p in sorted(glob.glob(d+'/*.csv')):
        for (ta,tl,hm,hl,post,r,sl) in run(p):
            print(f"{os.path.basename(d):7s} {os.path.basename(p)[:6]} apex@{ta:6.1f} HUDmin={hm:6.1f} land@{tl:6.1f} hland={hl:6.1f} post={post:6.1f} ratio={r:.3f} dh={hl-post:5.1f} postslope={sl:5.2f}/tk")

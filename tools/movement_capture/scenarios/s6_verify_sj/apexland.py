"""Verifier: landing-loss from apex HUD (vz~0 there, no vz0 pin needed) + drag 0.2."""
import csv,sys,glob,os,numpy as np
G=796.0; D=0.2
def load(p):
    T=[];S=[]
    for r in csv.DictReader(open(p)):
        if r['valid']!='1' or r['vel_scalar']=='': continue
        T.append(float(r['t'])*64+1); S.append(float(r['vel_scalar']))
    return np.array(T),np.array(S)
def events(T,S):
    # air segments: rise (jump) then U-shape then drop (landing)
    out=[]; i=1; n=len(S)
    while i<n-3:
        if S[i]-S[i-1]>12 and S[i+1]>=S[i]-3:   # takeoff rise
            j=i
            while j<n-1 and S[j+1]>=S[j]-3: j+=1   # climb to spike top
            # now descending into U; find landing: large drop after rising again
            k=j+1; mn=k
            while k<n-1:
                if S[k]<S[mn]: mn=k
                if S[k+1]-S[k]<-12 and k>mn+2: break
                k+=1
            if k>=n-1: break
            out.append((i,j,mn,k)); i=k+1
        else: i+=1
    return out
def analyse(p,lo=0,hi=1e9):
    T,S=load(p); res=[]
    for (i,j,mn,k) in events(T,S):
        if not(lo<=T[i]<=hi): continue
        t0=T[i]-0.5; tl=T[k]+0.5   # approx takeoff/landing ticks
        pre=S[max(0,i-6):i-1]; tp=T[max(0,i-6):i-1]
        g0=np.polyval(np.polyfit(tp,pre,1),t0) if len(pre)>=2 else np.nan
        hm=S[mn]; vz=-D*hm*hm/G; h=np.sqrt(max(hm*hm-vz*vz,0))
        h0=h*np.exp(D*(T[mn]-t0)/64); hl=h*np.exp(-D*(tl-T[mn])/64)
        # post-landing ground: skip transitional samples, take samples 1.5..10 ticks after
        m=(T>tl+1.5)&(T<tl+10)
        if m.sum()<3: continue
        post=np.polyval(np.polyfit(T[m],S[m],1),tl)
        res.append(dict(t0=t0,tl=tl,air=(tl-t0),g0=g0,h0=h0,hapex=h,hl=hl,post=post,r0=h0/g0,rl=post/hl))
    return res
if __name__=='__main__':
    for d in sys.argv[1:]:
        for p in sorted(glob.glob(d+'/*.csv')):
            for r in analyse(p):
                print(f"{os.path.basename(d):7s} {os.path.basename(p)[:6]} t0={r['t0']:6.1f} air={r['air']:5.1f}tk g0={r['g0']:6.1f} h0={r['h0']:6.1f} r0={r['r0']:.3f} hapex={r['hapex']:6.1f} hland={r['hl']:6.1f} post={r['post']:6.1f} rl={r['rl']:.3f}")

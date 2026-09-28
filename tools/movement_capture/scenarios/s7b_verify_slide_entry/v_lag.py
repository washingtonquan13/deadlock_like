# Independent verifier: fit HUD lag vs the sim ramp-up; read game speed at last-W tick; classify slide.
import csv, glob, json, sys, os
import numpy as np
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
def load_game(p):
    t=[];v=[]
    for r in csv.DictReader(open(p)):
        if r['valid']!='1' or r['vel_scalar']=='': continue
        t.append(float(r['t'])); v.append(float(r['vel_scalar']))
    return np.array(t), np.array(v)
def load_sim(p):
    k=[];v=[];l=[]
    for r in csv.DictReader(open(p)):
        k.append(int(r['tick'])); v.append(float(r['speed_h'])); l.append(r['loco'])
    return np.array(k,float), np.array(v), l
def lastW(sc):
    return max(e['to'] for e in json.load(open(sc))['timeline'] if e.get('move',[0,0])!=[0,0])
def fit_lag(tg, vg, ks, vs, lastw, lo=60, hi=330):
    tick = tg*64+1
    m = (vg>=lo)&(vg<=hi)&(tick<lastw+6)
    best=None
    for L in np.arange(0,10.01,0.05):
        pred=np.interp(tick[m]-L, ks, vs)
        r=np.sqrt(np.mean((pred-vg[m])**2))
        if best is None or r<best[1]: best=(L,r)
    return best, m.sum()
def game_at(tg,vg,simtick,L):
    return float(np.interp((simtick+L-1)/64.0, tg, vg))
if __name__=='__main__':
    sset = sys.argv[1]; names=sys.argv[2:]
    for n in names:
        sc=f'scenarios/{sset}/{n}.json'; N=lastW(sc)
        ks,vs,loco=load_sim(f'{ROOT}/tools_fit/_out/s7b_verify/{n}.csv')
        simslide = 'SLIDE' in loco[N:N+6]
        for p in sorted(glob.glob(f'rec_auto/{sset}/{n}/*_t?.csv')):
            tg,vg=load_game(p)
            (L,r),cnt=fit_lag(tg,vg,ks,vs,N)
            g=game_at(tg,vg,N,L); gp15=game_at(tg,vg,N+15,L); sp15=np.interp(N+15,ks,vs)
            print(f'{n} {os.path.basename(p)} N={N} lag={L:.2f} rms={r:.2f} n={cnt} game@N={g:.1f} sim@N={vs[int(N)]:.1f} game@N+15={gp15:.1f} sim@N+15={sp15:.1f} simslide={simslide}')

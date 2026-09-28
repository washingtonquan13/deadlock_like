"""Variants of the top-up for the fast diagonal cases; also print game pre-jump h estimate."""
import sys, os, json, math, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import v1
from v1 import *
def sim2(sc, yawd, variant):
    tl = sc['timeline']; T = 200; mv = [[0,0]]*(T+2); jumps = []
    for e in tl:
        for k in range(e['from'], e['to']+1):
            if 'move' in e: mv[k] = e['move']
            if 'jump' in e.get('buttons', []): jumps.append(k)
    v = np.zeros(2); ground = True; out = {}
    for k in range(1, T+1):
        raw = wish(mv[k], yawd); n = np.linalg.norm(raw); w = raw/n if n > 0 else raw
        if k == jumps[0]: ground = False
        if ground:
            sp = np.linalg.norm(v)
            if sp > 0: v *= max(0, sp - max(sp, 100)*4/64)/sp
            if n > 0:
                add = RUN - v@w
                if add > 0: v += w*min(add, 1600/64)
        else:
            if k == jumps[1]:
                out['pre'] = np.linalg.norm(v)
                pr = prevraw; pn = np.linalg.norm(pr)
                c = np.clip(pr, -1, 1); L = np.linalg.norm(c); cu = c/L; d = pr/pn
                if variant == 'A':   # proposal: along c
                    along = v@cu
                    if along < RUN: v = v + cu*min(200*L, RUN-along)
                elif variant == 'B': # along d (key dir) for the top-up
                    along = v@d
                    if along < RUN: v = v + cu*min(200*L, RUN-along)
                elif variant == 'C': # scale: add vector = c*200 scaled by topup fraction on d
                    along = v@d
                    if along < RUN: v = v + c*200*min(1, (RUN-along)/200)
                elif variant == 'D': # per-axis add then clip to target speed along c
                    along = v@cu
                    if along < RUN: v = v + cu*min(200*L, (RUN-along)*L)
            if n > 0:
                add = min(RUN, CAP) - v@w
                if add > 0: v += w*min(add, ACC)
            v *= (1 - DRAG/64)
        prevraw = raw; out[k] = v.copy()
    return out
for name, sd in [('DWA','s6_diag'),('DBSA','s6_diag'),('DGWD','double'),('DRWDY','s6_diag'),('DGRWD','double')]:
    sc = json.load(open(f'scenarios/{sd}/{name}.json'))
    fs = sorted(glob.glob(f'rec_auto/{sd}/{name}/ts1_t*.csv'))
    tick, hud, x, y, yawa = load(fs[0]); yawd = float(np.median(yawa))
    i = next(i for i in range(1, len(tick)) if tick[i] > 60 and hud[i]-hud[i-1] > 150); tj = tick[i]
    apex = hud[(tick > tj) & (tick < tj+70)].min()
    mm = (tick >= tj+30) & (tick <= tj+60)
    gh = (math.degrees(math.atan2(np.polyfit(tick[mm], y[mm], 1)[0], np.polyfit(tick[mm], x[mm], 1)[0])) - yawd + 180) % 360 - 180
    # game pre-jump: HUD just before the step, and vz of first jump pinned from its airtime is unknown -> print raw HUD
    print('%-6s game apex %.1f head %.2f  HUD[tj-1] %.1f' % (name, apex, gh, hud[i-1]))
    for var in 'ABCD':
        o = sim2(sc, yawd, var); aj = [e for e in sc['timeline'] if 'jump' in e.get('buttons', [])][1]['from']
        va = o[aj + 42]; vl = o[aj+45]
        print('   %s pre %.1f apex %.1f head %.2f' % (var, o['pre'], np.linalg.norm(va), (math.degrees(math.atan2(vl[1], vl[0]))-yawd+180)%360-180))

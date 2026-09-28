"""Independent verifier: apex HUD and late-flight heading after an air jump, game vs two add models."""
import csv, glob, json, math, os, sys
import numpy as np
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
G, DRAG, RUN, CAP, ACC, VZ = 796.0, 0.2, 386.0, 80.0, 2.0*386/64, 522.0

def load(f):
    rows = [r for r in csv.DictReader(open(f)) if r['valid'] == '1' and r['ang_yaw'] and r['pos_x'] and r['vel_scalar']]
    t = np.array([float(r['t']) for r in rows]); tick = np.round(t*64+1).astype(int)
    hud = np.array([float(r['vel_scalar']) for r in rows])
    x = np.array([float(r['pos_x']) for r in rows]); y = np.array([float(r['pos_y']) for r in rows])
    yaw = np.array([float(r['ang_yaw']) for r in rows])
    return tick, hud, x, y, yaw

def wish(move, yawd):
    # Source convention: forward=(cos,sin), right=(sin,-cos); move=[x(right), y(fwd)]
    a = math.radians(yawd); f = np.array([math.cos(a), math.sin(a)]); r = np.array([math.sin(a), -math.cos(a)])
    return f*move[1] + r*move[0]

def sim(sc, yawd, model, v0=None):
    tl = sc['timeline']; T = 200
    mv = [[0,0]]*(T+2); jumps = []
    for e in tl:
        for k in range(e['from'], e['to']+1):
            if 'move' in e: mv[k] = e['move']
            if 'jump' in e.get('buttons', []): jumps.append(k)
    v = np.zeros(2); onground = True; vz = 0; out = {}; prev = np.zeros(2); aj = None
    for k in range(1, T+1):
        raw = wish(mv[k], yawd); n = np.linalg.norm(raw); w = raw/n if n > 0 else raw
        if k == jumps[0]: onground = False
        if onground:  # ground: accel 1600 toward run, friction 4 (crude)
            sp = np.linalg.norm(v)
            if sp > 0: v *= max(0, sp - max(sp, 0)*4/64)/sp if sp > 0 else 1
            if n > 0:
                add = RUN - v@w
                if add > 0: v += w*min(add, 1600/64)
        else:
            if k == jumps[1]:
                aj = k
                pr = prevraw; pn = np.linalg.norm(pr)
                if pn > 0:
                    if model == 'norm': c = pr/pn; L = 1.0
                    else: c = np.clip(pr, -1, 1); L = np.linalg.norm(c); c = c/L
                    along = v@c
                    if along < RUN: v = v + c*min(200*L, RUN - along)
            if n > 0:
                add = min(RUN, CAP) - v@w
                if add > 0: v += w*min(add, ACC)
            v *= (1 - DRAG/64)
        prevraw = raw
        out[k] = v.copy()
    return out, aj

def main(sets):
    for d in sets:
        name = os.path.basename(d.rstrip('/'))
        scf = glob.glob(os.path.join(ROOT, 'scenarios', '*', name + '.json'))
        scf = [s for s in scf if 'fit' not in s]
        sc = json.load(open(scf[0]))
        res = []
        for f in sorted(glob.glob(d + '/ts1_t*.csv')):
            tick, hud, x, y, yawa = load(f)
            yawd = float(np.median(yawa))
            # air jump step: first tick > 60 with HUD rise > 150
            i = next((i for i in range(1, len(tick)) if tick[i] > 60 and hud[i] - hud[i-1] > 150), None)
            if i is None: print(name, 'no air-jump step'); break
            tj = tick[i]
            m = (tick > tj) & (tick < tj + 70)
            apex = hud[m].min()
            # late heading: camera velocity over tj+30..tj+60 (steady flight)
            mm = (tick >= tj+30) & (tick <= tj+60)
            px = np.polyfit(tick[mm], x[mm], 1)[0]; py = np.polyfit(tick[mm], y[mm], 1)[0]
            ang = math.degrees(math.atan2(py, px)) - yawd
            res.append((tj, apex, (ang+180) % 360 - 180, yawd, math.hypot(px, py)*64))
        r = np.array(res)
        line = '%-7s yaw %6.2f  n=%d tj %s apex %6.1f (sd %.1f)  late-head %7.2f (sd %.2f) camspd %5.1f' % (
            name, r[0,3], len(r), r[:,0].astype(int), r[:,1].mean(), r[:,1].std(), r[:,2].mean(), r[:,2].std(), r[:,4].mean())
        print(line)
        yawd = r[0,3]
        for model in ('norm', 'clamp'):
            o, aj = sim(sc, yawd, model)
            # apex tick ~ aj + VZ/G*64
            ka = aj + int(round(VZ/G*64))
            v = o[ka]; vlate = o[aj+45]
            ang = (math.degrees(math.atan2(vlate[1], vlate[0])) - yawd + 180) % 360 - 180
            print('        %-5s apex %6.1f  late-head %7.2f  spd@+45 %5.1f' % (model, np.linalg.norm(v), ang, np.linalg.norm(vlate)))

if __name__ == '__main__':
    main(sys.argv[1:])

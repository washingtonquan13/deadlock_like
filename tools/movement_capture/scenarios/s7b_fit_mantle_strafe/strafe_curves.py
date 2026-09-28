"""F: strafe run-speed ramp. Prints HUD speed (vel_scalar) at fixed times for FSW/FSD/FSA/FSWA trials,
and optionally a sim csv for comparison. Usage: python strafe_curves.py [sim_csv ...]"""
import csv, glob, os, sys
ROOT = os.path.join(os.path.dirname(__file__), '..', '..', 'rec_auto', 's7_open')
TS = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.8, 1.0, 1.2, 1.5, 2.0]
def load(p):
    rows = []
    with open(p) as f:
        for r in csv.DictReader(f):
            try:
                if r.get('valid', '1') in ('0', 'False', 'false'): continue
                rows.append((float(r['t']), float(r['vel_scalar'])))
            except (ValueError, KeyError): pass
    return rows
def at(rows, t):
    best = min(rows, key=lambda r: abs(r[0]-t)) if rows else None
    return best[1] if best and abs(best[0]-t) < 0.03 else float('nan')
def first_cross(rows, v):
    for t, s in rows:
        if s >= v: return t
    return float('nan')
print('name       ' + ' '.join('%6.2f' % t for t in TS) + '   t>=300 t>=380 max')
for name in ['FSW', 'FSD', 'FSA', 'FSWA']:
    for p in sorted(glob.glob(os.path.join(ROOT, name, '*.csv'))):
        rows = load(p)
        print('%-10s ' % (name + os.path.basename(p)[3:6]) + ' '.join('%6.1f' % at(rows, t) for t in TS),
              '  %5.3f %5.3f %6.1f' % (first_cross(rows, 300), first_cross(rows, 380), max(s for _, s in rows if _ < 2.4)))
for p in sys.argv[1:]:
    rows = []
    with open(p) as f:
        rd = csv.DictReader(f)
        for r in rd:
            keys = r.keys()
            t = float(r['t']) if 't' in r else (float(r['tick']) - 1) / 64.0
            if 'speed_h' in r: s = float(r['speed_h'])
            elif 'vel_scalar' in r: s = float(r['vel_scalar'])
            else:
                s = (float(r['vel_x'])**2 + float(r['vel_y'])**2) ** 0.5
            rows.append((t, s))
    print('%-10s ' % os.path.basename(p)[:10] + ' '.join('%6.1f' % at(rows, t) for t in TS),
          '  %5.3f %5.3f %6.1f' % (first_cross(rows, 300), first_cross(rows, 380), max(s for _, s in rows)))

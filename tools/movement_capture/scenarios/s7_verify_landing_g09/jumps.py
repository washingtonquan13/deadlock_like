"""Verifier: per-frame position jumps in s7_ramp game recordings (valid frames only)."""
import csv, glob, math, os, sys
root = os.path.join(os.path.dirname(__file__), '..', '..', 'rec_auto', 's7_ramp')
for f in sorted(glob.glob(os.path.join(root, '*', '*.csv'))):
    rows = [r for r in csv.DictReader(open(f)) if r['valid'] == '1']
    out = []
    for a, b in zip(rows, rows[1:]):
        dt = float(b['t']) - float(a['t'])
        dx = [float(b[k]) - float(a[k]) for k in ('pos_x', 'pos_y', 'pos_z')]
        dh = math.hypot(dx[0], dx[1]); dz = dx[2]
        hud = max(float(a['vel_scalar'] or 0), float(b['vel_scalar'] or 0))
        # implied speed vs HUD speed
        v = math.sqrt(dh*dh + dz*dz) / dt if dt > 0 else 0
        if dt <= 0 or v > 1.6 * hud + 150 or abs(dz) > 12:
            out.append(f"  t={float(b['t']):.3f} dt={dt*1000:.1f}ms dh={dh:.1f} dz={dz:.1f} impl={v:.0f} hud={hud:.0f}")
    t0 = float(rows[0]['t']); t1 = float(rows[-1]['t'])
    zs = [float(r['pos_z']) for r in rows]
    print(os.path.relpath(f, root), f"t {t0:.2f}..{t1:.2f} z {max(zs):.1f}->{min(zs):.1f} jumps={len(out)}")
    for o in out[:8]: print(o)

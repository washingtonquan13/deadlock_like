import csv, sys, os, numpy as np
D = sys.argv[1]
for n in ['FSW','FSD','FSA','FSWA']:
    R = list(csv.DictReader(open(os.path.join(D, n+'.csv'))))
    tick = np.array([int(r['tick']) for r in R]); sh = np.array([float(r['speed_h']) for r in R])
    t = (tick - 1) / 64.0
    def cross(v):
        i = np.where(sh >= v)[0][0]; return t[i-1] + (v-sh[i-1])/(sh[i]-sh[i-1])/64
    at = lambda q: sh[np.argmin(abs(t-q))]
    fl = [r for r in R][40]
    print(n, ' '.join(f'{at(q):.0f}' for q in [.2,.4,.6,.8,1.0,1.5,2.0]), f'x300 {cross(300):.3f} x380 {cross(380):.3f}', 'fwd/left@t40', fl['fwd'], fl['left'])

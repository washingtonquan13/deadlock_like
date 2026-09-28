import csv,sys,glob,math
import numpy as np
def load(p):
    R=[r for r in csv.DictReader(open(p)) if r['valid']=='1']
    a=np.array([[float(r['t']),float(r['pos_x']),float(r['pos_y']),float(r['pos_z']),float(r['vel_scalar']),float(r['ang_yaw']),float(r['ang_pitch'])] for r in R])
    a=np.c_[a[:,0]*64+1,a]
    return a
for name in sys.argv[1:]:
  for p in sorted(glob.glob(f'rec_auto/{name}/*_t?.csv')):
    a=load(p); print(p, 'yaw/pitch range',a[:,6].min(),a[:,6].max(),a[:,7].min(),a[:,7].max())
    tk=a[:,0]
    # windowed horizontal velocity from camera pos (fit over ~6 ticks)
    out=[]
    for c in range(20,160,4):
        m=(tk>=c-4)&(tk<=c+4)
        if m.sum()<3: continue
        t=a[m,1]
        vx=np.polyfit(t,a[m,2],1)[0]; vy=np.polyfit(t,a[m,3],1)[0]; vz=np.polyfit(t,a[m,4],1)[0]
        hud=np.interp(c,tk,a[:,5])
        h=math.hypot(vx,vy)
        out.append((c,h,vz,hud,math.sqrt(h*h+vz*vz)))
    for o in out: print(' tk%4d h_pos %6.1f vz_pos %7.1f HUD %6.1f  sqrt(h2+vz2) %6.1f'%o)

import csv,glob,math,sys,numpy as np
for p in sys.argv[1:]:
    R=[r for r in csv.DictReader(open(p)) if r['valid']=='1']
    print('==',p)
    y=None; prev=None
    for r in R:
        tk=float(r['t'])*64+1
        if tk<78 or tk>100: continue
        yaw=math.radians(float(r['ang_yaw']))
        x,yy,z=float(r['pos_x']),float(r['pos_y']),float(r['pos_z'])
        fw=x*math.cos(yaw)+yy*math.sin(yaw); la=x*math.sin(yaw)-yy*math.cos(yaw)
        d='' if prev is None else ' dfw %6.2f dla %6.2f dz %6.2f /dtick %.2f'%(fw-prev[0],la-prev[1],z-prev[2],tk-prev[3])
        print(' tk %6.2f fw %9.2f la %9.2f z %8.2f hud %6s%s'%(tk,fw,la,z,r['vel_scalar'],d)); prev=(fw,la,z,tk)

import csv,sys
f=sys.argv[1]; R=[r for r in csv.DictReader(open(f)) if r['valid']=='1']
x0,y0,z0=[float(R[0][k]) for k in('pos_x','pos_y','pos_z')]
for r in R:
  t=float(r['t']); 
  if t<float(sys.argv[2]) or t>float(sys.argv[3]): continue
  print('%.3f tick%5.1f  d=%7.1f z=%6.1f vz=%7s hud=%s'%(t,t*64+1,((float(r['pos_x'])-x0)**2+(float(r['pos_y'])-y0)**2)**.5,float(r['pos_z'])-z0,r['vel_z'],r['vel_scalar']))

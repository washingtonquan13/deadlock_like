import csv,glob,os
for d in sorted(glob.glob('rec_auto/mantle2/*')):
  for f in sorted(glob.glob(d+'/*.csv')):
    R=[r for r in csv.DictReader(open(f)) if r['valid']=='1']
    z0=float(R[0]['pos_z']); zs=[float(r['pos_z'])-z0 for r in R]
    p=[float(r['ang_pitch']) for r in R if r['ang_pitch']]
    v=[float(r['vel_scalar']) for r in R if r['vel_scalar']]
    zmax=max(zs); i=zs.index(zmax)
    print(os.path.basename(d),os.path.basename(f),'zmax %.1f t=%.2f zend %.1f pitch %.1f..%.1f vmax %.0f'%(zmax,float(R[i]['t']),zs[-1],min(p),max(p),max(v)))

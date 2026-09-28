import csv,glob,sys
for name in sys.argv[1:]:
  for f in sorted(glob.glob('rec_auto/s6_diag/%s/*.csv'%name)):
    R=[r for r in csv.DictReader(open(f)) if r['valid']=='1' and r['vel_scalar']]
    z0=float(R[0]['pos_z'])
    out=[]
    for r in R:
      tk=float(r['t'])*64+1
      if 150<=tk<=185: out.append('%d:%.0f/%.0f'%(round(tk),float(r['vel_scalar']),float(r['pos_z'])-z0))
    print(name,f[-10:],' '.join(out))

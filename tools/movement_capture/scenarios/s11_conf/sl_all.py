import subprocess,csv,glob,numpy as np,json,os,sys
os.chdir("C:/Godot Projects/deadlock_like/deadlock_like/tools/movement_capture")
ROOT=os.path.abspath("../.."); GD="D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
out=os.path.join(ROOT,"tools_fit","_out","s11_lc"); os.makedirs(out,exist_ok=True)
FIX={kv.split("=")[0]:float(kv.split("=")[1]) for a in sys.argv[1:] for kv in a.split(",")}
names=[os.path.basename(d) for d in sorted(glob.glob("rec_auto/s11_conf/S[LEC]*"))]
tot=[]
for n in names:
    s=json.load(open("scenarios/s11_conf/%s.json"%n)); s["fixed"]=FIX; T=s["ticks"]
    p=os.path.join(out,n+".json"); json.dump(s,open(p,"w")); c=p[:-5]+".csv"
    subprocess.run([GD,"--headless","--path",ROOT,"-s","res://tools_fit/route_export.gd","--","--scenario="+p.replace("\\","/"),"--out="+c.replace("\\","/")],capture_output=True,check=True)
    R=list(csv.DictReader(open(c))); tk=np.array([float(r["tick"]) for r in R]); sh=np.array([float(r["speed3d"]) for r in R])
    TK=np.arange(10,T-70,3); a=np.interp(TK,tk,sh)
    es=[]
    for g in sorted(glob.glob("rec_auto/s11_conf/%s/ts1_t?.csv"%n)):
        G=[r for r in csv.DictReader(open(g)) if r["valid"]=="1" and r["vel_scalar"] not in("","nan")]
        gt=np.array([float(r["t"])*64+1-2.7 for r in G]); v=np.array([float(r["vel_scalar"]) for r in G]); es.append(np.interp(TK,gt,v)-a)
    e=np.mean(es,axis=0); tot+=list(e)
    worst=np.argsort(-abs(e))[:3]
    print("%-5s rms %5.1f  worst %s"%(n,np.sqrt(np.mean(e**2))," ".join("t%d:%+.0f"%(TK[i],e[i]) for i in sorted(worst))))
print("ALL rms %.1f"%np.sqrt(np.mean(np.array(tot)**2)))

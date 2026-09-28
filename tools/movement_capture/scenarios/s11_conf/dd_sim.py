"""Down dash (DD*): game HUD speed (3D in the air, horizontal on the ground) vs the sim speed3d, lag-shifted 4.5 ticks
(these recordings run ~2 ticks behind the usual 2.7, the jump ascent included). Args: k=v overrides (hero.* for hero stats).
Usage: python tools/movement_capture/scenarios/s11_conf/dd_sim.py [k=v,...]; env LAG overrides the shift."""
import csv,glob,json,os,subprocess,sys,numpy as np
os.chdir("C:/Godot Projects/deadlock_like/deadlock_like/tools/movement_capture")
ROOT=os.path.abspath("../.."); GD="D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
out=os.path.join(ROOT,"tools_fit","_out","s11_dd"); os.makedirs(out,exist_ok=True)
FIX={kv.split("=")[0]:float(kv.split("=")[1]) for a in sys.argv[1:] for kv in a.split(",")}
tot=[]; LAG=float(os.environ.get("LAG","4.5"))
for n,t2 in (("DD_S",26),("DD_A",51),("DD_W",91),("DD_R",91),("DD_1",91),("DD_1W",91),("DD_AW",116)):
    s=json.load(open("scenarios/s11_conf/%s.json"%n)); s["fixed"]=FIX; p=os.path.join(out,n+".json"); json.dump(s,open(p,"w")); c=p[:-5]+".csv"
    subprocess.run([GD,"--headless","--path",ROOT,"-s","res://tools_fit/route_export.gd","--","--scenario="+p.replace("\\","/"),"--out="+c.replace("\\","/")],capture_output=True,check=True)
    R=list(csv.DictReader(open(c))); tk=np.array([float(r["tick"]) for r in R]); v=np.array([float(r["speed3d"]) for r in R])
    TT=list(range(t2-6,t2+56,3)); print(n," ".join("%4d"%t for t in TT)); print("  sim ", " ".join("%4.0f"%np.interp(t,tk,v) for t in TT))
    for g in sorted(glob.glob("rec_auto/s11_conf/%s/ts1_t?.csv"%n)):
        G=[r for r in csv.DictReader(open(g)) if r["vel_scalar"] not in("","nan")]
        gt=np.array([float(r["t"])*64+1-LAG for r in G]); gv=np.array([float(r["vel_scalar"]) for r in G])
        e=[np.interp(t,gt,gv) for t in TT]; tot+=list(np.array(e)-[np.interp(t,tk,v) for t in TT]); print("  game"," ".join("%4.0f"%q for q in e))
print("rms %.1f"%np.sqrt(np.mean(np.square(tot))))

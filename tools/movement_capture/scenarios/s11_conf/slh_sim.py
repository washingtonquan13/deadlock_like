"""G09 clear time via SLH3..32 (landing slide, hop 2 k ticks after hop 1's landing): game HUD vs sim speed3d around
hop 2, lag LAG (env, default 4.5). Args: k=v overrides."""
import csv,glob,json,os,subprocess,sys,numpy as np
os.chdir("C:/Godot Projects/deadlock_like/deadlock_like/tools/movement_capture")
ROOT=os.path.abspath("../.."); GD="D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
out=os.path.join(ROOT,"tools_fit","_out","s11_slh"); os.makedirs(out,exist_ok=True)
FIX={kv.split("=")[0]:float(kv.split("=")[1]) for a in sys.argv[1:] for kv in a.split(",")}
LAG=float(os.environ.get("LAG","4.5")); OFF=list(range(-6,50,4)); tot=[]
print("off from hop 2   "," ".join("%4d"%o for o in OFF))
for k in (3,8,13,18,24,32):
    n="SLH%d"%k; h=77+k
    s=json.load(open("scenarios/s11_conf/%s.json"%n)); s["fixed"]=FIX; p=os.path.join(out,n+".json"); json.dump(s,open(p,"w")); c=p[:-5]+".csv"
    subprocess.run([GD,"--headless","--path",ROOT,"-s","res://tools_fit/route_export.gd","--","--scenario="+p.replace("\\","/"),"--out="+c.replace("\\","/")],capture_output=True,check=True)
    R=list(csv.DictReader(open(c))); tk=np.array([float(r["tick"]) for r in R]); v=np.array([float(r["speed3d"]) for r in R]); lo=[r["loco"] for r in R]
    sv=[np.interp(h+o,tk,v) for o in OFF]; print("%-6s sim  "%n," ".join("%4.0f"%q for q in sv), " loco@hop-1 %s"%lo[h-1])
    for g in sorted(glob.glob("rec_auto/s11_conf/%s/ts1_t?.csv"%n)):
        G=[r for r in csv.DictReader(open(g)) if r["vel_scalar"] not in("","nan")]
        gt=np.array([float(r["t"])*64+1-LAG for r in G]); gv=np.array([float(r["vel_scalar"]) for r in G])
        e=[np.interp(h+o,gt,gv) for o in OFF]; tot+=list(np.array(e)-sv); print("       game "," ".join("%4.0f"%q for q in e))
if tot: print("rms %.1f"%np.sqrt(np.mean(np.square(tot))))

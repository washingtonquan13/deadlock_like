"""Heavy air recovery (HM_A, HM_AW): sim speed3d/up (melee -> heavy bit after HOLD ticks, pitch -14.7) vs game HUD and
camera z, lag-shifted by LAG (env, default 4.5). Args: k=v overrides. The lunge edge lines up at LAG 2.7; fit with LAG=2.7 T0=84 T1=116 DT=1."""
import csv,glob,json,os,subprocess,sys,numpy as np
os.chdir("C:/Godot Projects/deadlock_like/deadlock_like/tools/movement_capture")
ROOT=os.path.abspath("../.."); GD="D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
out=os.path.join(ROOT,"tools_fit","_out","s11_hma"); os.makedirs(out,exist_ok=True)
FIX={kv.split("=")[0]:float(kv.split("=")[1]) for a in sys.argv[1:] for kv in a.split(",")}
LAG=float(os.environ.get("LAG","4.5")); HOLD=13; tot=[]
for n in ("HM_A","HM_AW"):
    s=json.load(open("scenarios/s11_conf/%s.json"%n)); s["fixed"]=FIX; s["start"]["pitch_deg"]=-14.7
    for e in s["timeline"]:
        if e.get("buttons")==["melee"]: e["from"]+=HOLD; e["buttons"]=["melee_heavy"]
    p=os.path.join(out,n+".json"); json.dump(s,open(p,"w")); c=p[:-5]+".csv"
    subprocess.run([GD,"--headless","--path",ROOT,"-s","res://tools_fit/route_export.gd","--","--scenario="+p.replace("\\","/"),"--out="+c.replace("\\","/")],capture_output=True,check=True)
    R=list(csv.DictReader(open(c))); tk=np.array([float(r["tick"]) for r in R]); v=np.array([float(r["speed3d"]) for r in R]); up=np.array([float(r["up"]) for r in R])
    lo=[r["loco"] for r in R]
    TT=list(range(int(os.environ.get("T0","40")),int(os.environ.get("T1","140")),int(os.environ.get("DT","4")))); print(n,"    "," ".join("%4d"%t for t in TT)); print("  sim  v"," ".join("%4.0f"%np.interp(t,tk,v) for t in TT))
    print("  sim  z"," ".join("%4.0f"%np.interp(t,tk,up) for t in TT)); print("  loco  "," ".join("%4s"%lo[min(int(t),len(lo)-1)][:4] for t in TT))
    for g in sorted(glob.glob("rec_auto/s11_conf/%s/ts1_t?.csv"%n)):
        G=[r for r in csv.DictReader(open(g)) if r["vel_scalar"] not in("","nan") and r["pos_z"] not in("","nan")]
        gt=np.array([float(r["t"])*64+1-LAG for r in G]); gv=np.array([float(r["vel_scalar"]) for r in G]); gz=np.array([float(r["pos_z"]) for r in G]); gz-=gz[0]
        e=[np.interp(t,gt,gv) for t in TT]; tot+=list(np.array(e)-[np.interp(t,tk,v) for t in TT])
        print("  game v"," ".join("%4.0f"%q for q in e)); print("  game z"," ".join("%4.0f"%np.interp(t,gt,gz) for t in TT))
if tot: print("rms %.1f"%np.sqrt(np.mean(np.square(tot))))

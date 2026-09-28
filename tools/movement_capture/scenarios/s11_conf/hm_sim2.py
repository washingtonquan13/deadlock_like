"""Heavy melee recovery and cooldown: sim replay vs game (HM_R, HM_C, HM_C2). A melee hold maps to the sim's heavy
bit held from HOLD ticks after the key goes down (input_sampler sets it continuously once the hold passes 0.2 s).
Prints every lunge onset (scripted ticks; the game is lag-shifted by 2.7) and HM_R's speed after the first lunge."""
import json, os, glob, subprocess, sys, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "wall"))
os.environ.setdefault("MARK", "street_y058b")
from analyze import track
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
GODOT = "D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
OUT = os.path.join(ROOT, "tools_fit", "_out", "s11_hm"); os.makedirs(OUT, exist_ok=True)
HOLD = 13
def sim(name):
    s = json.load(open(os.path.join(os.path.dirname(__file__), name + ".json")))
    s["start"]["pitch_deg"] = -14.7
    for e in s["timeline"]:
        if e.get("buttons") == ["melee"]:
            e["from"] += HOLD; e["buttons"] = ["melee_heavy"]
    sp = os.path.join(OUT, name + "_h.json"); json.dump(s, open(sp, "w"), indent=1)
    out = os.path.join(OUT, name + "_h.csv")
    subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", "res://tools_fit/route_export.gd", "--",
                    "--scenario=" + sp, "--out=" + out], capture_output=True)
    return np.genfromtxt(out, delimiter=",", names=True)
def onsets(tk, sp):
    d = np.diff(np.r_[sp[0], sp]); r = []
    for i in np.where(d > 80)[0]:
        if not r or tk[i] - r[-1] > 40: r.append(tk[i])
    return r
for name in sys.argv[1:] or ["HM_R", "HM_C", "HM_C2"]:
    a = sim(name); tk = a["tick"]; s3 = a["speed3d"]
    on = onsets(tk, s3)
    print("## %s sim onsets %s" % (name, on))
    if name == "HM_R":
        k = int(np.searchsorted(tk, on[0])); e = k + int(np.argmax(s3[k:] < 200))
        print("   sim after lunge end (tick %d), per 4 ticks: %s" % (tk[e], " ".join("%.0f" % v for v in s3[e:e + 60:4])))
    for p in sorted(glob.glob(os.path.join(ROOT, "tools/movement_capture/rec_auto/s11_conf/%s/*.csv" % name))):
        t, f, l, z, spd, yaw = track(p); g = t * 64 + 1 - 2.7
        m = t > 0.3; o = onsets(g[m], spd[m])
        line = "   game onsets %s" % ["%.0f" % v for v in o]
        if name == "HM_R" and o:
            k = int(np.searchsorted(g, o[0])); e = k + int(np.argmax(spd[k:] < 200)); ge = g[e]
            prof = [spd[min(len(spd) - 1, np.searchsorted(g, ge + j))] for j in range(0, 60, 4)]
            line += "  after lunge end (%.0f): %s" % (ge, " ".join("%.0f" % v for v in prof))
        print(line)

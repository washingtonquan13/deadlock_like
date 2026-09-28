"""Heavy melee: sim replay vs game. The sim's heavy button is the committed heavy: the game commits ~13 ticks
(0.22 s, input_sampler.heavy_hold_time) after the melee key goes down, so the replay presses melee_heavy then.
Prints the HUD-style speed per 2 ticks from the lunge onset (game: HUD; sim: 3D speed) and the settled distance."""
import json, os, glob, subprocess, sys, numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "wall"))
os.environ.setdefault("MARK", "street_y058b")
from analyze import track
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
GODOT = "D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
OUT = os.path.join(ROOT, "tools_fit", "_out", "s11_hm"); os.makedirs(OUT, exist_ok=True)
HOLD = 13
FIX = {}
for a in [x for x in sys.argv[1:] if x.startswith("--set=")]:
    sys.argv.remove(a)
    for kv in a[6:].split(","):
        k, v = kv.split("="); FIX[k] = float(v)
def sim(name):
    s = json.load(open(os.path.join(os.path.dirname(__file__), name + ".json")))
    s["start"]["pitch_deg"] = -14.7; s["fixed"] = FIX
    for e in s["timeline"]:
        if e.get("buttons") == ["melee"]:
            e["from"] = e["to"] = e["from"] + HOLD; e["buttons"] = ["melee_heavy"]
    sp = os.path.join(OUT, name + ".json"); json.dump(s, open(sp, "w"), indent=1)
    out = os.path.join(OUT, name + ".csv")
    subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", "res://tools_fit/route_export.gd", "--",
                    "--scenario=" + sp, "--out=" + out], capture_output=True, check=True)
    a = np.genfromtxt(out, delimiter=",", names=True)
    return a
for name in sys.argv[1:] or ["HM_S", "HM_W", "HM_J"]:
    a = sim(name)
    s3 = a["speed3d"]
    k0 = int(np.argmax((a["tick"][1:] > 20) & (np.diff(s3) > 100))) + 1         # first lunge tick
    fw = a["fwd"]
    print("## %s  sim onset tick %d  2-tick: %s  d %.0f u" % (name, a["tick"][k0], " ".join("%.0f" % v for v in s3[k0:k0 + 30:2]),
          fw[min(k0 + 57, len(fw) - 1)] - fw[k0 - 3]))
    for p in sorted(glob.glob(os.path.join(ROOT, "tools/movement_capture/rec_auto/s11_conf/%s/*.csv" % name))):
        t, f, l, z, spd, yaw = track(p)
        g = t * 64 + 1; i = np.where((t > 0.6) & (np.diff(np.r_[0, spd]) > 50))[0][0]; on = g[i]
        prof = [spd[max(0, np.searchsorted(g, on + k + 0.5) - 1)] for k in range(0, 30, 2)]
        print("   game onset %.1f (-2.7 lag = %.1f)  2-tick: %s  d %.0f u" % (on, on - 2.7, " ".join("%.0f" % v for v in prof),
              np.interp(on / 64 + 0.9, t, f) - np.interp(on / 64 - 0.05, t, f)))

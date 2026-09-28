"""gen_old.py: builds sim scenarios (s6_adfit/<SET>_<probe>.json) from the old A_probe/A_air driver inputs.json."""
import json, os, glob
MC = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.dirname(os.path.abspath(__file__))
tmpl = json.load(open(os.path.join(MC, "scenarios", "s6_airdash", "E386S.json")))
HERO = {"b1": "hero_haze", "b2": None, "b3": None}
KEYS = {"w": [0, 1], "s": [0, -1], "a": [-1, 0], "d": [1, 0]}
BTN = {"space": "jump", "lshift": "dash", "ctrl": "crouch"}
for f in sorted(glob.glob(os.path.join(MC, "rec_auto", "A_*_b1", "*_t1_inputs.json"))):
    setn = os.path.basename(os.path.dirname(f)); probe = os.path.basename(f).split("_")[0]
    ev = json.load(open(f))["inputs"]; down = {}; tl = []
    last = max(e["tick"] for e in ev)
    for e in ev:
        k, a, t = e["kind"], e["arg"], e["tick"]
        if k == "down": down[a] = t
        else:
            t0 = down.pop(a)
            if a in KEYS: tl.append({"from": t0, "to": t - 1, "move": KEYS[a]})
            elif a in BTN: tl.append({"from": t0, "to": t0, "buttons": [BTN[a]]})
    for a, t0 in down.items():
        if a in KEYS: tl.append({"from": t0, "to": 150, "move": KEYS[a]})
    sc = dict(tmpl); sc["name"] = sc["clip"] = "%s_%s" % (setn, probe); sc["timeline"] = tl; sc["ticks"] = 150
    sc["record"] = {"src": os.path.relpath(f, MC)}
    sc["start"] = dict(tmpl["start"]); sc["start"]["sprint_on"] = True
    json.dump(sc, open(os.path.join(OUT, sc["name"] + ".json"), "w"), indent=1)
    print(sc["name"], tl)

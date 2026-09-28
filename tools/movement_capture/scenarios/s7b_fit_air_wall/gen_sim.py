"""Writes sim replay scenarios (Haze, sprint on, same timelines) for NK1/NK2 (s7_open) and the wallA wall jumps
(s7_open WJD/WJA, s3 wall WJD/WJA/WJ0/WJWA/WJSA). The wall face is 10.16 m (the game's contact distance from the
start, camera track) + capsule radius ahead (-Z). Variant files <SET>_<NAME>_<tag>.json carry "fixed" param
overrides (a scratch copy; src untouched). Usage (from this folder): python gen_sim.py"""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
U = 0.0254
VARIANTS = {"cur": {}, "prop": {"wall_jump_kick_tangent": 107 * U}, "prop105": {"wall_jump_kick_tangent": 105 * U}}
CASES = [("s7_open", n) for n in ("NK1", "NK2", "WJD", "WJA")] + [("wall", n) for n in ("WJD", "WJA", "WJ0", "WJWA", "WJSA")]
for st, n in CASES:
    s = json.load(open(os.path.join(HERE, "..", st, n + ".json")))
    s["hero"] = "res://data/movement/heroes/hero_haze.tres"; s["suppress_sprint"] = False
    s["start"]["sprint_on"] = True
    s["params"] = [{"name": "air_accel", "min": 0, "max": 100, "note": "placeholder (value unchanged)"}]
    if n.startswith("WJ"):
        face = 10.16 + 0.4064
        s["geometry"] = [{"type": "wall", "center": [0.0, 5.0, -(face + 0.25)], "size": [40.0, 10.0, 0.5]}]
    for tag, fx in VARIANTS.items():
        if n.startswith("NK") and tag != "cur": continue
        s2 = dict(s); s2["fixed"] = fx; s2["name"] = "%s_%s_%s" % (st, n, tag)
        json.dump(s2, open(os.path.join(HERE, "%s_%s_%s.json" % (st, n, tag)), "w"), indent=1)
print("ok")

"""Wall probes (session 3). Mark wall1: Haze on the sidewalk facing a brick building wall.
Probe scenarios first find the wall (W into it) and its orientation (W+A / W+D slide along it)."""
import json
def base(name, comment, T):
    return {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
            "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0}, "ticks": T,
            "default": {"move": [0, 0], "buttons": []}, "timeline": []}
S = {}
s = base("WW", "walk W into the wall for 3 s", 200); s["timeline"].append({"from": 1, "to": 200, "move": [0, 1]}); S["WW"] = s
s = base("WWA", "W+A into the wall", 200); s["timeline"].append({"from": 1, "to": 200, "move": [-1, 1]}); S["WWA"] = s
s = base("WWD", "W+D into the wall", 200); s["timeline"].append({"from": 1, "to": 200, "move": [1, 1]}); S["WWD"] = s
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)

# ---- wall jumps at mark wallA (head-on, wall 10.16 m ahead; walking reaches it at ~1.3 s).
# W from tick 1, ground jump at tick 60 (~6.6 m), airborne contact ~tick 83, wall jump pressed at tick 88.
# After tick 83 the key under test replaces W.
WJT = 260
def wj(name, comment, keys, second_jump=True):
    s = base(name, comment, WJT)
    s["timeline"] += [{"from": 1, "to": 83, "move": [0, 1]}, {"from": 60, "to": 60, "buttons": ["jump"]}]
    if keys is not None:
        s["timeline"].append({"from": 84, "to": 150, "move": keys})
    if second_jump:
        s["timeline"].append({"from": 88, "to": 88, "buttons": ["jump"]})
    return s
S2 = {"WJX": wj("WJX", "jump into the wall, no second jump, W held on", [0, 1], False),
      "WJ0": wj("WJ0", "wall jump, no key", None),
      "WJW": wj("WJW", "wall jump, W held", [0, 1]),
      "WJS": wj("WJS", "wall jump, S held", [0, -1]),
      "WJA": wj("WJA", "wall jump, A held", [-1, 0]),
      "WJD": wj("WJD", "wall jump, D held", [1, 0])}
for k, v in S2.items():
    json.dump(v, open(k + ".json", "w"), indent=1)

# ---- more wall jumps: diagonals, a late press (falling: set vs add vertical), and approach-angle variants
def wj2(name, comment, keys, press=88, release=83, T=WJT):
    s = base(name, comment, T)
    s["timeline"] += [{"from": 1, "to": release, "move": [0, 1]}, {"from": 60, "to": 60, "buttons": ["jump"]},
                      {"from": press, "to": press, "buttons": ["jump"]}]
    if keys is not None:
        s["timeline"].append({"from": release + 1, "to": 160, "move": keys})
    return s
S3 = {"WJWA": wj2("WJWA", "wall jump, W+A", [-1, 1]),
      "WJSA": wj2("WJSA", "wall jump, S+A", [-1, -1]),
      "WJ0L": wj2("WJ0L", "neutral wall jump pressed late (tick 104, falling along the wall)", None, press=104),
      # mark wallA25: same spot, facing 25 deg left of the wall normal; contact ~tick 90
      "AWJ0": wj2("AWJ0", "angled approach (wallA25), neutral wall jump", None, press=96, release=90),
      "AWJX": wj2("AWJX", "angled approach (wallA25), W held on, no wall jump", [0, 1], press=9999, release=90),
      "AWW": base("AWW", "angled walk into the wall (wallA25)", 200)}
S3["AWW"]["timeline"].append({"from": 1, "to": 200, "move": [0, 1]})
# dash / dash slide into the wall. Head-on at wallA, angled at wallA25.
def dash_into(name, comment, slide):
    s = base(name, comment, 200)
    if slide:
        s["timeline"] += [{"from": 1, "to": 23, "move": [0, 1]}, {"from": 4, "to": 4, "buttons": ["dash"]},
                          {"from": 24, "to": 200, "buttons": ["crouch"]}]
    else:
        s["timeline"] += [{"from": 1, "to": 200, "move": [0, 1]}, {"from": 30, "to": 30, "buttons": ["dash"]}]
    return s
for pre, c in (("", "head-on (wallA)"), ("A", "angled (wallA25)")):
    S3[pre + "DW"] = dash_into(pre + "DW", "ground dash into the wall, W held, " + c, False)
    S3[pre + "SW"] = dash_into(pre + "SW", "dash slide into the wall, crouch held, no keys, " + c, True)
for k, v in S3.items():
    json.dump(v, open(k + ".json", "w"), indent=1)

# ---- rising contact (vertical set vs add) and a 45 deg approach (mark wallA45, x 2736: wall 300 u ahead)
S4 = {"WJ0E": wj2("WJ0E", "neutral wall jump while still rising: ground jump at tick 76, press at 85", None, press=85),
      "BWW": base("BWW", "45 deg walk into the wall (wallA45)", 200),
      "BWJ0": wj2("BWJ0", "45 deg approach (wallA45), neutral wall jump", None, press=80, release=76),
      "BWJS": wj2("BWJS", "45 deg approach (wallA45), wall jump with S", [0, -1], press=80, release=76)}
S4["WJ0E"]["timeline"][1] = {"from": 76, "to": 76, "buttons": ["jump"]}
S4["BWW"]["timeline"].append({"from": 1, "to": 200, "move": [0, 1]})
for nm in ("BWJ0", "BWJS"):
    S4[nm]["timeline"][1] = {"from": 50, "to": 50, "buttons": ["jump"]}
for k, v in S4.items():
    json.dump(v, open(k + ".json", "w"), indent=1)

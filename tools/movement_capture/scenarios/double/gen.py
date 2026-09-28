"""Double (air) jump probes (session 4). Mark street. Walk W, ground jump at tick 40, air jump at 40+k.
Keys from the air jump on are under test: does the air jump set or add vz, and does it redirect horizontal speed?"""
import json
J = 40
def base(name, comment, T=200):
    return {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
            "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0}, "ticks": T,
            "default": {"move": [0, 0], "buttons": []}, "timeline": []}
def dbl(name, comment, k, after, walk=True, pre=(0, 1)):
    s = base(name, comment)
    if walk:
        s["timeline"].append({"from": 1, "to": J + k - 1, "move": list(pre)})
    s["timeline"].append({"from": J, "to": J, "buttons": ["jump"]})
    s["timeline"].append({"from": J + k, "to": J + k, "buttons": ["jump"]})
    if after is not None:
        s["timeline"].append({"from": J + k, "to": 170, "move": after})
    return s
S = {}
for k in (8, 16, 24, 36):
    S["DBW%d" % k] = dbl("DBW%d" % k, "walk, jump, air jump %d ticks later, W held throughout (vz rule)" % k, k, [0, 1])
S["DB0"] = dbl("DB0", "walk, jump, air jump at +24, no key from the air jump (horizontal kept?)", 24, None)
S["DBS"] = dbl("DBS", "walk, jump, air jump at +24, S from the air jump (redirect backwards?)", 24, [0, -1])
S["DBD"] = dbl("DBD", "walk, jump, air jump at +24, D from the air jump (redirect sideways?)", 24, [1, 0])
S["DBR"] = dbl("DBR", "standing jump, air jump at +24 with D from the air jump (burst from rest?)", 24, [1, 0], walk=False)
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)

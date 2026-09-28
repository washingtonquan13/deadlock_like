"""Air steering probes (session 3). Mark street: Haze on the street, long open run ahead (yaw 102.72).
Walk W, ground jump at tick 40 (full walk speed), then the key under test from tick 41 until landing."""
import json
def base(name, comment, T=200):
    return {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
            "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0}, "ticks": T,
            "default": {"move": [0, 0], "buttons": []}, "timeline": []}
def walkjump(name, comment, keys, walk=True):
    s = base(name, comment)
    if walk:
        s["timeline"].append({"from": 1, "to": 40, "move": [0, 1]})
    s["timeline"].append({"from": 40, "to": 40, "buttons": ["jump"]})
    if keys is not None:
        s["timeline"].append({"from": 41, "to": 130, "move": keys})
    return s
S = {"AW": walkjump("AW", "walk, jump, W held in the air", [0, 1]),
     "A0": walkjump("A0", "walk, jump, no key in the air (drag baseline)", None),
     "AS": walkjump("AS", "walk, jump, S held in the air (opposing accel)", [0, -1]),
     "AD": walkjump("AD", "walk, jump, D held in the air (sideways accel)", [1, 0]),
     "RW": walkjump("RW", "standing jump, W in the air (accel from rest to the cap)", [0, 1], walk=False),
     "RD": walkjump("RD", "standing jump, D in the air", [1, 0], walk=False)}
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)

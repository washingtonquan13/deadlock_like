"""Mantle probe scenarios. W held from rest toward the obstacle; jump at tick J (MJnn), optional W release tick."""
import json, os
D = os.path.dirname(__file__)
def scen(name, ticks, w_to, jumps, comment):
    tl = [{"from": 1, "to": w_to, "move": [0, 1]}] if w_to else []
    tl += [{"from": j, "to": j, "buttons": ["jump"]} for j in jumps]
    s = {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
         "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0}, "ticks": ticks,
         "default": {"move": [0, 0], "buttons": []}, "timeline": tl}
    json.dump(s, open(os.path.join(D, name + ".json"), "w"), indent=1)
scen("MW", 150, 150, [], "W held into the obstacle, no jump")
# crateA mark: crate face ~6.35 m ahead, contact ~tick 57
for j in (30, 38, 44, 50, 56, 70):
    scen("MJ%03d" % j, 220, 220, [j], "W held, jump at tick %d" % j)
for j in (44, 56):
    scen("MJ%03dR" % j, 220, j, [j], "W held until the jump at tick %d, then released" % j)
# crouch held from the jump on (mantle glide?)
for j in (44, 56):
    s = json.load(open(os.path.join(D, "MJ%03d.json" % j)))
    s["name"] = s["clip"] = "MJ%03dC" % j; s["_comment"] += ", crouch held from the jump on"
    s["timeline"].append({"from": j, "to": 220, "buttons": ["crouch"]})
    json.dump(s, open(os.path.join(D, s["name"] + ".json"), "w"), indent=1)

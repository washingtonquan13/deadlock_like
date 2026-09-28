"""Repeat wall jumps (fatigue), session 4. Mark wallA (head-on). As WJW: W held throughout, ground jump at 60,
first wall jump at 88. W pulls the hero back to the wall, re-contact ~tick 137 (WJW), so press again then."""
import json
T = 300
def sc(name, comment, presses):
    tl = [{"from": 1, "to": T - 20, "move": [0, 1]}, {"from": 60, "to": 60, "buttons": ["jump"]}]
    tl += [{"from": p, "to": p, "buttons": ["jump"]} for p in presses]
    return {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
            "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0}, "ticks": T,
            "default": {"move": [0, 0], "buttons": []}, "timeline": tl}
S = {}
for p2 in (138, 141, 144):
    S["WF2_%d" % p2] = sc("WF2_%d" % p2, "wall jumps at 88 and %d, W held" % p2, [88, p2])
for p3 in (186, 192):
    S["WF3_%d" % p3] = sc("WF3_%d" % p3, "wall jumps at 88, 141 and %d, W held" % p3, [88, 141, p3])
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)

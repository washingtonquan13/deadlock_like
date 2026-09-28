"""Taller-ledge mantle probes (session 4). Mark truckA: box-truck cargo side ~175 u ahead, top ~162 u above the street.
W held from rest toward the truck; TW never jumps, TJnnn jumps once at tick nnn. Contact is ~tick 47 when jumping at 40."""
import json, os
D = os.path.dirname(__file__)
def scen(name, ticks, jumps, comment, crouch=None):
    tl = [{"from": 1, "to": ticks, "move": [0, 1]}] + [{"from": j, "to": j, "buttons": ["jump"]} for j in jumps]
    if crouch:
        tl.append({"from": crouch, "to": ticks, "buttons": ["crouch"]})
    s = {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
         "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0}, "ticks": ticks,
         "default": {"move": [0, 0], "buttons": []}, "timeline": tl}
    json.dump(s, open(os.path.join(D, name + ".json"), "w"), indent=1)
scen("TW", 120, [], "W held into the truck, no jump")
for j in (30, 40, 46, 50, 60):
    scen("TJ%03d" % j, 150, [j], "W held, jump at tick %d" % j)

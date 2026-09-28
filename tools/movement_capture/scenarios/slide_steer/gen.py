"""Slide-steering probes (session 3). Dash with W at tick 4, crouch held from tick 24 (inside the dash-jump
window, so a dash slide at ~650 u/s), W released at 24. Steering input starts at tick 32.
Mouse turns: yaw ramps 1.5 deg/tick (96 deg/s) to the right (yaw decreasing) for 40 ticks = 60 deg."""
import json
T = 130
def base(name, comment):
    return {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
            "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0}, "ticks": T,
            "default": {"move": [0, 0], "buttons": []},
            "timeline": [{"from": 1, "to": 23, "move": [0, 1]}, {"from": 4, "to": 4, "buttons": ["dash"]},
                         {"from": 24, "to": T, "buttons": ["crouch"]}]}
def turn(sc, rate=-1.5, n=40, start=32):
    for i in range(n):
        sc["timeline"].append({"from": start + i, "to": start + i if i < n - 1 else T, "yaw_deg": rate * (i + 1)})
S = {}
S["SL0"] = base("SL0", "baseline dash slide, no input after tick 23")
s = base("SLD", "D held from tick 32"); s["timeline"].append({"from": 32, "to": T, "move": [1, 0]}); S["SLD"] = s
s = base("SLWD", "W+D held from tick 32"); s["timeline"].append({"from": 32, "to": T, "move": [1, 1]}); S["SLWD"] = s
s = base("SLM", "mouse turn right 60 deg over 40 ticks from tick 32, no keys"); turn(s); S["SLM"] = s
s = base("SLWM", "W held + mouse turn right from tick 32"); s["timeline"].append({"from": 32, "to": T, "move": [0, 1]}); turn(s); S["SLWM"] = s
s = base("SLDM", "D held + mouse turn right from tick 32"); s["timeline"].append({"from": 32, "to": T, "move": [1, 0]}); turn(s); S["SLDM"] = s
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)

"""S (back) during a slide (session 4). Mark street_y148. Dash slide as slide_steer (W 1..23, dash 4, crouch from 24).
The curb at ~680 u restarts the slide clock (see lslide), so compare against SL0 recorded here too."""
import json
T = 160
def base(name, comment):
    return {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
            "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0}, "ticks": T,
            "default": {"move": [0, 0], "buttons": []},
            "timeline": [{"from": 1, "to": 23, "move": [0, 1]}, {"from": 4, "to": 4, "buttons": ["dash"]},
                         {"from": 24, "to": T - 10, "buttons": ["crouch"]}]}
S = {"SB0": base("SB0", "baseline dash slide, no input after tick 23")}
for n, c, a, mv in [("SBS", "S held from 32", 32, [0, -1]), ("SBSD", "S+D held from 32", 32, [1, -1]),
                    ("SBS60", "S held from 60", 60, [0, -1])]:
    s = base(n, c); s["timeline"].append({"from": a, "to": T - 10, "move": mv}); S[n] = s
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)

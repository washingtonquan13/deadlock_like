"""Slide-hop / bunny-hop probes (session 4). Mark street_y148 (clear runway).
Dash slide as in slide_steer: W 1..23, dash at 4, crouch held from 24 (a dash slide at ~650 u/s)."""
import json
S0 = 24   # slide start tick
def base(name, comment, T=200):
    return {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
            "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0}, "ticks": T,
            "default": {"move": [0, 0], "buttons": []}, "timeline": []}
def slide(name, comment, crouch_to=190, T=200):
    s = base(name, comment, T)
    s["timeline"] += [{"from": 1, "to": 23, "move": [0, 1]}, {"from": 4, "to": 4, "buttons": ["dash"]},
                      {"from": S0, "to": crouch_to, "buttons": ["crouch"]}]
    return s
def press(s, *ticks):
    for k in ticks:
        s["timeline"].append({"from": k, "to": k, "buttons": ["jump"]})
S = {}
# stage 1: single hops (arc, landing tick, air drag with and without the slide-hop flag)
s = slide("SHJ19", "slide jump 0.3 s into the dash slide, crouch held throughout (lands into a slide)"); press(s, S0 + 19); S["SHJ19"] = s
s = slide("SHJ40", "slide jump 0.625 s into the dash slide, crouch held throughout"); press(s, S0 + 40); S["SHJ40"] = s
s = slide("SHJ19R", "slide jump 0.3 s in, crouch released at the jump (lands standing)", crouch_to=S0 + 18); press(s, S0 + 19); S["SHJ19R"] = s
s = base("BHH", "walk W, jump held from tick 40 to 170 (does a held jump re-hop on landing?)")
s["timeline"] += [{"from": 1, "to": 170, "move": [0, 1]}, {"from": 40, "to": 170, "buttons": ["jump"]}]; S["BHH"] = s
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)
# stage 2: the cut (slide speed at the jump), a non-dash slide, re-pressed crouch in the air, press-timed bhops
S = {}
for k in (3, 10, 60):
    s = slide("SHJ%d" % k, "slide jump %d ticks into the dash slide, crouch held throughout" % k); press(s, S0 + k); S["SHJ%d" % k] = s
s = slide("SHJ19P", "slide jump 0.3 s in, crouch released at the jump, pressed again 30 ticks later (landing slide?)", crouch_to=S0 + 18)
press(s, S0 + 19); s["timeline"].append({"from": S0 + 49, "to": 190, "buttons": ["crouch"]}); S["SHJ19P"] = s
# landing slide (not a dash slide): dash jump as DJC2 (dash 4, jump 31, crouch from 97, lands ~101), jump 20 ticks after landing
s = base("SLDJ", "dash jump, crouch before landing (landing slide ~567), slide jump ~20 ticks after landing")
s["timeline"] += [{"from": 1, "to": 31, "move": [0, 1]}, {"from": 4, "to": 4, "buttons": ["dash"]}, {"from": 31, "to": 31, "buttons": ["jump"]},
                  {"from": 97, "to": 190, "buttons": ["crouch"]}]
press(s, 121); S["SLDJ"] = s
for d in (2, 8):
    s = base("BHP%d" % d, "walk W, jump at 40 (lands ~88), jump pressed again at 88+%d" % d)
    s["timeline"] += [{"from": 1, "to": 170, "move": [0, 1]}]; press(s, 40, 88 + d); S["BHP%d" % d] = s
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)

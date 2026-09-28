"""Dash-jump probes (session 4). Mark street. W held, ground dash on tick 4, jump press at tick 4+k.
The model's window is 0.30-0.55 s after the dash (k ~19..35); a press before it is assumed to lock the dash jump out."""
import json
D = 4
def base(name, comment, T=220):
    return {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
            "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0}, "ticks": T,
            "default": {"move": [0, 0], "buttons": []}, "timeline": []}
def dj(name, comment, jumps, after=None, crouch_from=None):
    s = base(name, comment)
    last = max(jumps) if jumps else 60
    s["timeline"].append({"from": 1, "to": D + last, "move": [0, 1]})
    s["timeline"].append({"from": D, "to": D, "buttons": ["dash"]})
    for k in jumps:
        s["timeline"].append({"from": D + k, "to": D + k, "buttons": ["jump"]})
    if after is not None:
        s["timeline"].append({"from": D + last + 1, "to": 200, "move": after})
    if crouch_from is not None:
        s["timeline"].append({"from": D + crouch_from, "to": 215, "buttons": ["crouch"]})
    return s
S = {}
for k in (12, 18, 20, 22, 27, 33, 36, 40):
    S["DJ%d" % k] = dj("DJ%d" % k, "dash, jump %d ticks after the dash, no key after" % k, [k])
S["DJL"] = dj("DJL", "dash, early jump at 12 then again at 27 (does the early press lock the dash jump?)", [12, 27])
S["DJW"] = dj("DJW", "dash jump at 27, W held after (air-control bonus?)", [27], after=[0, 1])
S["DJS"] = dj("DJS", "dash jump at 27, S held after (air-control bonus?)", [27], after=[0, -1])
S["DJC"] = dj("DJC", "dash jump at 27, crouch held from tick 27+30 (dash-jump slide on landing)", [27], crouch_from=57)
# follow-up batch: window edges, when a plain jump works again after the dash, landing cut (clamp or multiplier?),
# crouch timed at touchdown (landing ~tick 101 for a jump at k=27)
for k in (19, 34, 35, 44, 48, 52):
    S["DJ%d" % k] = dj("DJ%d" % k, "dash, jump %d ticks after the dash, no key after" % k, [k])
sb = dj("DJSb", "dash jump at 27, S held for 20 ticks after (land slower: is the landing cut a clamp or a multiplier?)", [27])
sb["timeline"].append({"from": D + 28, "to": D + 47, "move": [0, -1]})
S["DJSb"] = sb
S["DJC2"] = dj("DJC2", "dash jump at 27, crouch held from ~4 ticks before touchdown", [27], crouch_from=93)
S["DJC3"] = dj("DJC3", "dash jump at 27, crouch held from ~2 ticks after touchdown", [27], crouch_from=99)
for k, v in S.items():
    json.dump(v, open(k + ".json", "w"), indent=1)

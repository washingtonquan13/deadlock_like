"""Landing-slide onset probes (session 4). Mark street_y148.
Dash jump as DJC (W 1..31, dash 4, jump 31), S held in the air from tick 40 for k ticks to shorten the run
(and set the landing speed), crouch held from 61 to 250 (lands into a dash-jump slide if fast enough)."""
import json
def sc(name, k):
    tl = [{"from": 1, "to": 31, "move": [0, 1]}, {"from": 4, "to": 4, "buttons": ["dash"]},
          {"from": 31, "to": 31, "buttons": ["jump"]}, {"from": 61, "to": 250, "buttons": ["crouch"]}]
    if k:
        tl.append({"from": 40, "to": 39 + k, "move": [0, -1]})
    return {"_comment": "dash jump, S in the air for %d ticks from 40, crouch 61..250 (landing slide onset)" % k,
            "name": name, "clip": name, "up_axis": "z", "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0},
            "ticks": 260, "default": {"move": [0, 0], "buttons": []}, "timeline": tl}
for k in (12, 20, 26, 30, 36):
    json.dump(sc("LSD%d" % k, k), open("LSD%d.json" % k, "w"), indent=1)
# stage 2: does it matter whether S is held when crouch goes down?
def sc2(name, comment, s_to, crouch_from, walk=False):
    if walk:
        tl = [{"from": 1, "to": 40, "move": [0, 1]}, {"from": 40, "to": 40, "buttons": ["jump"]}]
        s_from = 50
    else:
        tl = [{"from": 1, "to": 31, "move": [0, 1]}, {"from": 4, "to": 4, "buttons": ["dash"]},
              {"from": 31, "to": 31, "buttons": ["jump"]}]
        s_from = 40
    if s_to:
        tl.append({"from": s_from, "to": s_to, "move": [0, -1]})
    tl.append({"from": crouch_from, "to": 250, "buttons": ["crouch"]})
    return {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
            "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0},
            "ticks": 260, "default": {"move": [0, 0], "buttons": []}, "timeline": tl}
for n, c, a, b, w in [("LSA", "as LSD20 (S 40..59) but crouch from 55, while S is held", 59, 55, False),
                      ("LSB", "as LSD26 (S 40..65) but crouch from 70, after S", 65, 70, False),
                      ("LSW", "walk jump at 40, crouch from 70 (no S)", 0, 70, True),
                      ("LSWS", "walk jump at 40, S 50..62, crouch from 58 (while S held)", 62, 58, True)]:
    json.dump(sc2(n, c, a, b, w), open(n + ".json", "w"), indent=1)
# stage 3: onset anchor. LSD12's onset (~145) sits ~44 ticks after landing but ~141 after the dash; SL0 (ground dash slide) is ~64
# after the slide start. Shift the jump alone (LSJ20), shift everything (LSX16), and start a ground dash slide later (SLC).
def sc3(name, comment, w_to, dash, jump, crouch_from, s=None, T=260):
    tl = [{"from": 1, "to": w_to, "move": [0, 1]}, {"from": dash, "to": dash, "buttons": ["dash"]}]
    if jump:
        tl.append({"from": jump, "to": jump, "buttons": ["jump"]})
    if s:
        tl.append({"from": s[0], "to": s[1], "move": [0, -1]})
    tl.append({"from": crouch_from, "to": T - 10, "buttons": ["crouch"]})
    return {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
            "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0},
            "ticks": T, "default": {"move": [0, 0], "buttons": []}, "timeline": tl}
for n, c, a in [("LSJ20", "as LSD12 but the jump at 20 (dash still at 4)", (20, 4, 20, 50, (29, 40))),
                ("LSX16", "LSD12 shifted 16 ticks later (W 1..47, dash 20, jump 47, S 56..67, crouch 77)", (47, 20, 47, 77, (56, 67))),
                ("SLC", "ground dash slide with crouch from 34 instead of 24 (W 1..33, dash 4)", (33, 4, 0, 34, None))]:
    json.dump(sc3(n, c, *a, T=280), open(n + ".json", "w"), indent=1)

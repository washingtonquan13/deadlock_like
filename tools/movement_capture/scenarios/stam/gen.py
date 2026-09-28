"""Stamina counting and air jumps after dash/wall jumps (session 4). Fast stamina OFF (citadel_enable_fast_stamina 0).
Charges are counted by how many later ground dashes still work (regen is ~4.5 s per charge, longer than a run).
Mark street_y148 unless noted; W held throughout."""
import json, os
D = os.path.dirname(os.path.abspath(__file__))
def sc(name, comment, presses, T=240, w=(1, 235)):
    tl = [{"from": w[0], "to": w[1], "move": [0, 1]}]
    tl += [{"from": t, "to": t, "buttons": [b]} for t, b in presses]
    s = {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
         "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0}, "ticks": T,
         "default": {"move": [0, 0], "buttons": []}, "timeline": tl}
    json.dump(s, open(os.path.join(D, name + ".json"), "w"), indent=1)
sc("SC0", "4 ground dashes 46 ticks apart: counts the charges (3 expected)", [(4, "dash"), (50, "dash"), (96, "dash"), (142, "dash")], T=200)
sc("SCAJ", "jump 4, air jump 20, then ground dashes at 115/161/207: 2 work if the air jump costs 1",
   [(4, "jump"), (20, "jump"), (115, "dash"), (161, "dash"), (207, "dash")], T=260)
sc("SCDJ", "dash 4, jump 31 (dash jump), then dashes at 110/156: 1 works if dash + dash jump cost 2",
   [(4, "dash"), (31, "jump"), (110, "dash"), (156, "dash")], T=210)
sc("DJAJ", "dash jump (dash 4, jump 31), air jump at 50: allowed? vz and horizontal after", [(4, "dash"), (31, "jump"), (50, "jump")], T=180)
sc("DJAJ70", "dash jump, air jump at 70 (falling)", [(4, "dash"), (31, "jump"), (70, "jump")], T=180)
# regen timing: spend 3 charges, then try a dash every 16 ticks
sc("SCR", "dashes at 4/50/96 (all charges), then a dash press every 16 ticks from 150: first success = regen time",
   [(4, "dash"), (50, "dash"), (96, "dash")] + [(t, "dash") for t in range(150, 420, 16)], T=430, w=(1, 425))
# SCR hit the runway end. SCR2 alternates W / S so the hero stays near the mark.
def scr2():
    tl, presses = [], []
    wins = [(1, 47), (48, 95), (96, 143)] + [(t, t + 23) for t in range(144, 430, 24)]
    for i, (a, b) in enumerate(wins):
        tl.append({"from": a, "to": b, "move": [0, 1 if i % 2 == 0 else -1]})
        tl.append({"from": a + 4, "to": a + 4, "buttons": ["dash"]})
    s = {"_comment": "3 dashes (W/S/W) spend all charges, then a dash every 24 ticks alternating W/S: first success = regen time",
         "name": "SCR2", "clip": "SCR2", "up_axis": "z", "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0},
         "ticks": 440, "default": {"move": [0, 0], "buttons": []}, "timeline": tl}
    json.dump(s, open(os.path.join(D, "SCR2.json"), "w"), indent=1)
scr2()
# Regen is ~140 ticks per charge from use (SC0 vs SCR2), so SCAJ is inconclusive. SAJ: spend 2 charges (W/S dashes),
# then jump 100 + air jump 110 + air dash 120, all before the first charge returns (~148): the air dash only works
# if the air jump left the last charge. SAJ0: same without the air jump (control).
def saj(name, aj):
    tl = [{"from": 1, "to": 47, "move": [0, 1]}, {"from": 4, "to": 4, "buttons": ["dash"]},
          {"from": 48, "to": 95, "move": [0, -1]}, {"from": 52, "to": 52, "buttons": ["dash"]},
          {"from": 96, "to": 200, "move": [0, 1]}, {"from": 100, "to": 100, "buttons": ["jump"]},
          {"from": 120, "to": 120, "buttons": ["dash"]}]
    if aj:
        tl.append({"from": 110, "to": 110, "buttons": ["jump"]})
    s = {"_comment": "2 dashes, jump 100%s, air dash 120" % (", air jump 110" if aj else ""), "name": name, "clip": name,
         "up_axis": "z", "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0}, "ticks": 210,
         "default": {"move": [0, 0], "buttons": []}, "timeline": tl}
    json.dump(s, open(os.path.join(D, name + ".json"), "w"), indent=1)
saj("SAJ", True); saj("SAJ0", False)

"""Stamina regen with fast stamina and rapid regen OFF (driver setup now sends citadel_disable_fast_stamina and
citadel_rapid_stamina_regen false). Mark street_y148.
SWnnn: dashes at 5/52/100 (W/S/W) spend the charges, no input until nnn, then 3 dashes 24 ticks apart (S/W/S):
the count that fires = charges back nnn ticks into the recovery."""
import json, os
D = os.path.dirname(os.path.abspath(__file__))
def sw(T):
    wins = [(1, 47, 1), (48, 95, -1), (96, 110, 1), (T - 4, T + 19, -1), (T + 20, T + 43, 1), (T + 44, T + 67, -1)]
    tl = []
    for a, b, m in wins:
        tl.append({"from": a, "to": b, "move": [0, m]})
    for t in (5, 52, 100, T, T + 24, T + 48):
        tl.append({"from": t, "to": t, "buttons": ["dash"]})
    name = "SW%03d" % T
    s = {"_comment": __doc__.splitlines()[2], "name": name, "clip": name, "up_axis": "z",
         "start": {"pos_m": [0, 0, 0], "yaw_deg": 0.0, "stamina": 3.0}, "ticks": T + 80,
         "default": {"move": [0, 0], "buttons": []}, "timeline": tl}
    json.dump(s, open(os.path.join(D, name + ".json"), "w"), indent=1)
for T in (200, 260, 320, 380, 440, 520):
    sw(T)

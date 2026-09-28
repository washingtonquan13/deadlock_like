"""Mixed-movement route for a game vs sim comparison (mark street_y148, fast stamina off).
Each segment is (from, to, move) plus one-tick presses. Laid out with the sim so the hero stays in the clear
part of the runway (the curb is ~680 u ahead). Keys: move [x, y] with x = D(+)/A(-), y = W(+)/S(-)."""
import json, os
D = os.path.dirname(os.path.abspath(__file__))

def route(name, T, moves, presses, holds=(), comment=""):
    tl = [{"from": a, "to": b, "move": m} for a, b, m in moves]
    tl += [{"from": t, "to": t, "buttons": [b]} for t, b in presses]
    tl += [{"from": a, "to": b, "buttons": [bt]} for a, b, bt in holds]
    s = {"_comment": comment, "name": name, "clip": name, "up_axis": "z",
         "start": {"pos_m": [0, 0, 0], "yaw_deg": 147.66, "stamina": 3.0, "sprint_on": True}, "ticks": T,
         "default": {"move": [0, 0], "buttons": []}, "timeline": tl, "suppress_sprint": False,
         "hero": "res://data/movement/heroes/hero_haze.tres",
         "params": [{"name": "air_accel", "min": 0, "max": 100, "note": "placeholder: the sim replay needs one (value unchanged)"}]}
    json.dump(s, open(os.path.join(D, name + ".json"), "w"), indent=1)

W, S, A_, D_, WA, WD, SD, SA, N = [0, 1], [0, -1], [-1, 0], [1, 0], [-1, 1], [1, 1], [1, -1], [-1, -1], [0, 0]
route("R1", 580,
      moves=[(1, 50, W), (51, 125, S), (126, 150, SD), (151, 225, N), (226, 329, W), (330, 345, WA), (346, 375, W),
             (376, 495, S), (496, 580, N)],
      presses=[(12, "dash"), (95, "jump"), (140, "jump"), (355, "jump"), (458, "dash")],
      holds=[(318, 360, "crouch"), (415, 445, "crouch")],
      comment="walk+dash W, S brake/backpedal, jump back, air jump S+D, coast; W, crouch slide with W+A steer, slide hop; "
              "S with crouch-walk back, then S dash; release")

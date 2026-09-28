"""Save a mark at a known hero position (for spots where driver.py mark's camera-point teleport would fall, e.g. on a
slope or a ledge). Run from tools/movement_capture: mkmark.py NAME X Y Z YAW PITCH.
Z is the hero ground z from a drop scan (probe.py, CAMDZ-corrected); the hero is set there, turned, and the HUD it then
shows is stored as the mark's hud point (what driver.py run checks)."""
import sys, os, json
HERE = os.path.dirname(os.path.abspath(__file__)); MC = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(MC, "driver"))
import driver as D, gameio as gio
cfg = D.config(); a = sys.argv[1:]
name = a[0]; pawn = [float(v) for v in a[1:4]]; yaw = float(a[4]); pitch = float(a[5])
gio.focus_game(cfg["exe"])
hud = D.Hud(cfg)
gio.console(["setpos %.3f %.3f %.3f" % tuple(pawn)], cfg["console_key"], cfg["exe"])
hud.wait_still(timeout=15)
D.turn_to(hud, cfg, D.wrap180(yaw), pitch)
v = hud.wait_still(timeout=10)
h = [v["pos_x"], v["pos_y"], v["pos_z"]]
marks = D.load_json(D.MARKS, {})
marks[name] = {"pawn": pawn, "hud": h, "yaw": v["ang_yaw"], "pitch": v["ang_pitch"],
               "cam_offset": [h[i] - pawn[i] for i in range(3)], "return_error_u": 0.0}
D.save_json(D.MARKS, marks)
print("mark %s = %s" % (name, json.dumps(marks[name])))

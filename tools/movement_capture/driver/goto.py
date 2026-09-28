"""Teleport to a mark (or raw pawn x y z) and face a yaw: goto.py NAME [YAW] | goto.py X Y Z YAW [PITCH]."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import driver as D, gameio as gio
cfg = D.config(); a = sys.argv[1:]
if len(a) >= 4:
    pawn = [float(v) for v in a[:3]]; yaw = float(a[3]); pitch = float(a[4]) if len(a) > 4 else 14.69
else:
    m = D.load_json(D.MARKS, {})[a[0]]; pawn = m["pawn"]; yaw = float(a[1]) if len(a) > 1 else m["yaw"]; pitch = m["pitch"]
gio.focus_game(cfg["exe"])
hud = D.Hud(cfg)
gio.console(["setpos %.3f %.3f %.3f" % tuple(pawn)], cfg["console_key"], cfg["exe"])
hud.wait_still(timeout=15)
D.turn_to(hud, cfg, D.wrap180(yaw), pitch)

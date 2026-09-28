"""Make marks at the street spot facing other yaws: setpos to the street hero position, turn, `mark`.
Usage: mkmarks.py YAW [YAW ...]  -> marks street_yNNN (NNN = yaw rounded, 0..359)."""
import sys, os, types
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "driver"))
import driver as D, gameio as gio
cfg = D.config()
base = D.load_json(D.MARKS, {})["street"]
gio.focus_game(cfg["exe"])
hud = D.Hud(cfg)
for y in sys.argv[1:]:
    y = float(y) % 360.0
    gio.console(["setpos %.3f %.3f %.3f" % tuple(base["pawn"])], cfg["console_key"], cfg["exe"])
    hud.wait_still(timeout=15)
    D.turn_to(hud, cfg, D.wrap180(y), base["pitch"])
    D.cmd_mark(types.SimpleNamespace(name="street_y%03d" % round(y)), cfg)

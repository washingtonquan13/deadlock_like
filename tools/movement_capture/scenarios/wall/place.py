"""place.py X Y Z YAW [PITCH]: teleport the hero and turn the camera (then use driver.py mark NAME)."""
import sys, time
sys.path.insert(0, "driver"); sys.path.insert(0, ".")
import gameio as gio, driver as d
cfg = d.config(); hud = d.Hud(cfg)
gio.focus_game()
x, y, z, yaw = map(float, sys.argv[1:5]); pitch = float(sys.argv[5]) if len(sys.argv) > 5 else None
gio.console(["setpos %.3f %.3f %.3f" % (x, y, z)], cfg["console_key"], cfg["exe"])
hud.wait_still(timeout=15)
print(d.turn_to(hud, cfg, yaw, pitch))

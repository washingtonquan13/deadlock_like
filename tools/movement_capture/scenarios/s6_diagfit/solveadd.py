"""Given pre (HUD apex h along the pre direction) and the clamped-wish direction c^, solve the add size a along c^
that reproduces the HUD h after the air jump; report along = v.c^ after and a/L."""
import math, numpy as np, importlib.util, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from clampmodel import cases, cvec, ang  # noqa (prints tables on import)
pre_h = {"DWA": 337.8, "DGWD": 338.1, "DGBSD": 337.7, "DGBSA": 337.9, "DBSA": 168.4}
print("\n%-6s %5s %6s %7s %6s %7s %7s %6s" % ("case", "L", "v.c", "HUDh", "a", "a/L", "along", "ang_c"))
for n, yaw, k, pre, pa, aa, hh, cp in cases:
    if n not in pre_h and n != "R1": continue
    v = np.array(pre, float); v = v/np.linalg.norm(v)*pre_h.get(n, np.linalg.norm(v))
    c = cvec(yaw, k); L = np.linalg.norm(c); d = c/L; al = v@d
    perp2 = v@v - al*al; a = math.sqrt(max(hh*hh - perp2, 0)) - al
    print("%-6s %5.3f %6.1f %7.1f %6.1f %7.1f %7.1f %6.2f" % (n, L, al, hh, a, a/L, al+a, ang(d)))

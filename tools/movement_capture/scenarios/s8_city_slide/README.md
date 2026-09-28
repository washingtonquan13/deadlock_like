# s8 city slide: crouch slides down NYC stair ramps (video OCR)

Clips: `rec/2026-09-28 10-38-{26,33,42,51}.mp4` (v1..v4, not in git). They are 1920x1080 at 60 fps, with the
cl_showpos overlay at the top left. Each is a normal crouch slide from a run, with stamina full the whole time.

## OCR (`ocr/`)

1. `dump.py` crops y 220-360, x 0-640 into `v?.npy` (ffmpeg comes from pip `imageio-ffmpeg`).
2. `run_ocr.py` (with `ocr2.py`) reads pos and vel from the crops and writes `v?.csv` (columns frame, x, y, z, vel,
   velmax, score).
   - Method: grayscale NCC template match, ±2 px shift.
   - Templates come from 6 hand-labelled lines.
   - All 12 held-out lines read correctly.

cl_showpos `vel` is the horizontal speed: its integral equals the horizontal path length.

## Fits

- `slope.py`, `fit.py`: windowed accel against slope and speed.
- `ode.py`: fits dv/dt = k·g·tanθ − f·v over the ramp segments of v1..v3.
  - With f = 0.19 (the flat slide friction), the best k is 0.99 (rms 22 u/s).

## Replay

`replay.gd` builds a straight ramp (angle, drop) with a flat top and bottom. It runs W from rest, then crouches at
the top edge. For v3: `--angle=29.5 --drop=413 --runup=155`.

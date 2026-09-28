# Session 8: slides down long city ramps (NYC stair ramps, video OCR)

Recordings: four clips from 2026-09-28 (v1..v4). Each is a normal crouch slide from a run down a 25-30° stair ramp
onto a flat, and one clip (v4) has two ramps. Data and scripts are in `tools/movement_capture/scenarios/s8_city_slide`.
cl_showpos `vel` was read by OCR; it is the horizontal speed.

| Clip | Ramp | Drop | Speed on the ramp | Bottom → penalty knee |
|---|---|---|---|---|
| v1 | 29.8° | 281 u | 277 → 605 | 0.60 s |
| v2 | 29.9° | 274 u | 425 → 668 | (stairs up after the flat) |
| v3 | 29.3° | 413 u | 402 → 754 in 1.18 s | 0.60 s |
| v4 | 25.2° (×2) | 109 u, 157 u | 397 → 610 | 0.57 s, 0.57 s |

## The penalty never starts on the ramp

- The sharp slowdown comes 0.57-0.60 s after reaching the flat, however long the ramp took. On v3 the slide is 1.3 s
  old at the bottom and 1.9 s old at the knee.
- 0.60 s is the ground-press onset from session 7 (`slide_onset_table_ground`).
- Model: the penalty timer restarts every tick of downhill sliding on a slide slope. This is a new
  `MoveState.slide_penalty_ticks`; `slide_ticks` keeps counting for the slide-jump windows.
- PROVISIONAL: restart and hold are not yet separated, because every clip crouched at the top edge. A flat slide into
  a ramp would separate them.

## Slope accel is g·tanθ with the ordinary slide friction

- A fit of dv/dt = k·g·tanθ − f·v on v1..v3 gives k = 0.99 at f = 0.19 (rms 22 u/s).
  - With f = 0, the best k is 0.77, which is worse (rms 29).
- `slide_slope_friction` goes 0 → 0.1875, the same value as `slide_friction`.
- Session 7's "friction 0" came from RBOT, where the penalty-timer error was absorbed into the fit. With the timer rule,
  0.1875 also fits ramp1 better:

  | Case | Game | Old sim (f = 0) | New sim (f = 0.1875) |
  |---|---|---|---|
  | RBOT peak | 457 | 479 | 460 |
  | RRUN peak | 514 | 570 | 532 |

- Flat decay between the bottom and the knee is ~0.19/s, the slide friction.

## Slide entry reads the along-surface speed

- In s7 RRUN, the HUD running down the 26.5° ramp rises from 347 to ~390. That is h / cosθ: the run speed is
  horizontal, and the HUD shows the speed along the surface.
- A crouch there slides, although the horizontal speed was below 350.
- The ground crouch entry test now uses the along-surface speed, so RRUN and RJ slide in the replay again. They broke
  when `slide_entry_speed` became 350 in session 7b.
- Crouching at rest or at crouch-walk speed on a ramp is unchanged: 187 / cos 26.5 = 209, still no slide.

## Replay (v3, `s8_city_slide/replay.gd`)

| | Game | Sim |
|---|---|---|
| Time on the ramp | 1.3 s | 1.25 s |
| Bottom speed | 750 | 790 (+5%) |
| Bottom → knee | 0.55 s | 0.6 s |

## Open

- Restart vs hold of the timer (needs a flat slide carried onto a ramp).
- A smooth (non-stair) ramp at a second angle, to pin k.
- A slide carried onto an upslope.

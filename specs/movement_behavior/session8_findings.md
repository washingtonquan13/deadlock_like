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
- Crouching at rest, or crouch-walking onto a ramp with crouch already held, does not slide (see the sliding_3 section).

## Replay (v3, `s8_city_slide/replay.gd`)

| | Game | Sim |
|---|---|---|
| Time on the ramp | 1.3 s | 1.25 s |
| Bottom speed | 750 | 790 (+5%) |
| Bottom → knee | 0.55 s | 0.6 s |

## sliding_2 clips (w1-w3, `s8_city_slide/ocr/w*.csv`)

- **The wiki's "slides on a ramp" rule.** It holds in the along-surface form only.
  - w1: Haze runs from rest over a ~30° stair ramp and crouches at HUD ~331, which is horizontal ≈ run speed 323,
    below the flat 350. It slides, with the HUD then rising ~10/frame (g·tanθ).
  - w3 is the same case at ~330-347.
  - Both fit the along-surface test: 323 / cos 30 ≈ 373 > 350.
  - s7 RS0 (crouch at rest on ramp1) and RSW (crouch-walk 187 down ramp1) still show no slide in the game. So "any
    speed on a ramp" is not what the game does.
  - Unmeasured: a crouch while running down a ramp with the along-surface speed below 350. Examples are a slow hero
    such as Abrams (252 u/s) on ~26°, or Haze on a ~10-15° ramp.
- **w2 is a mantle glide out of the mid-boss pit.**
  - The HUD freezes during the climb. The exit runs 11 frames at 177 (the mantle exit speed), then the glide starts at
    540.8 with crouch held (known ~537).
  - The glide decays at ~0.19/s on the flat, then runs into the upward stairs (~28°).
  - There the slide ends at once: 488 → 190 in ~11 frames (~5.5/s), then crouch-walk 187 up the stairs. The user
    confirms that sliding up is blocked in the game.
  - Model: SLIDE → CROUCH when moving uphill on a slide slope.
  - The sim decays at ground friction 4/s, a bit slower than ~5.5. RUP's ~400 u/s² tail below 100 hints at an extra
    uphill g·tanθ term in crouch. That is not modelled.

## sliding_3 x1 and the 11-17-35 clip: "or when on a ramp"

- **x1 (`ocr/x1.csv`):**
  - The hero stands at the top of a 20-26° stair ramp and walks off.
  - Crouch is pressed at ~70-100 u/s: the crouch pose is at frames 9-12, the slide VFX from frame 24.
  - It slides, and the HUD climbs a steady ~460 u/s² to 435 at the bottom. That is well above g·tanθ (~390 at 26°).
    The rate is the same at 190 and 362 u/s, so there is almost no speed-proportional friction here.
- **11-17-35.mkv (`ocr/y1.csv`):**
  - Crouch at rest, then a crouch-walk at 187 on the flat and down a ~35° ramp.
  - It stays at 187 the whole way, with no slide.
- **The user confirms:** from rest it never slides; crouching and then walking onto a ramp keeps you crouching.
- **Rule (GROUND branch):** a crouch press slides when the along-surface speed is above 350, or when moving downhill
  on a slide slope at any speed above 0. The CROUCH state only uses the 350 test.
- **Replay:** `replay.gd --angle=25 --drop=110 --runup=4 --crouch_at=6`.
  - Sim: 100 → 407 at the bottom, ~300 u/s² on the ramp.
  - Game: 435 at the bottom, ~460 u/s².
  - The ramp accel model (k·g·tanθ − f·v, session 8 fit k 0.99, f 0.19) is too weak at low speed. A joint fit over
    v1-v3 and x1 does not converge, because the stair-ramp angles from OCR z are too noisy (x1: 20-26°).

## Open

- Restart vs hold of the timer (needs a flat slide carried onto a ramp).
- A smooth (non-stair) ramp at a second angle, to pin k.
- Crouch friction uphill (~5.5/s game vs 4/s sim); a possible g·tanθ term on crouch/ground movement on slopes.
- Ramp slide accel at low speed: game ~460 u/s² at 190-360 u/s on 20-26° vs sim ~300. This needs a smooth ramp of known angle, with a slow-crouch slide and a fast one on it.

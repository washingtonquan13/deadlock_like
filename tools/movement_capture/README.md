# movement_capture: from a Deadlock recording to fitted movement numbers

This is a clean-room pipeline. It uses only what the game shows on screen (the `cl_showpos` overlay in a screen
recording). It never reads game files, memory or network traffic, and it does not use Valve code or assets.
See `specs/_measurement_protocol.md` for the rules.

```
record (OBS) -> calibrate ROI -> extract CSV -> write/adjust scenario -> fit (Godot, headless) -> review -> apply to .tres (by hand)
```

| Piece | Where | What it does |
|---|---|---|
| `extract.py` | here | Reads the video and the `cl_showpos` text, then writes one CSV row per video frame in z-up game units (u, u/s) |
| `mc_ocr.py`, `mc_post.py` | here | Handle OCR (RapidOCR or trained glyph templates), parsing, outlier rejection and monotonic time |
| `layouts/showpos_default.json` | here | Describes the overlay text layout. The format is **assumed**, so check it against your first real recording |
| `synth.py`, `tests/` | here | Build synthetic overlay videos with known values and run the accuracy tests |
| `scenarios/*.json` | here | Describe the inputs, geometry, alignment and free parameters for one recorded clip |
| `res://tools_fit/fit_runner.gd` | Godot | Replays a scenario in `MovementSim` and fits the parameters to the CSV |
| `res://tools_fit/fit_selftest.gd` | Godot | Checks that the fitter recovers known values from sim-generated data |
| `res://tools_fit/scenario_probe.gd` | Godot | Runs a scenario once and prints the sim trace (locomotion changes, speeds), to line up timeline ticks before fitting |

## 1. Setup (once)

Use the Windows Python 3.12 install. Only pip packages are needed: OpenCV headless, numpy and RapidOCR (onnxruntime).

```
cd "C:\Godot Projects\deadlock_like\deadlock_like\tools\movement_capture"
"C:\Users\Quan Washington\AppData\Local\Programs\Python\Python312\python.exe" -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe -m unittest discover -s tests -v     (about 45 s. Set MC_SKIP_RAPIDOCR=1 to skip the slow test)
```

The folder has a `.gdignore` so Godot does not import the venv or the videos.

## 2. Recording

**OBS settings** (from the shot list in the protocol):
- 120 fps if your machine can hold it, otherwise at least 60 fps.
- Game capture, with the canvas and output at the **native game resolution**, no scaling.
- CBR at a high bitrate (for example 40–60 Mbps at 1080p120), so compression does not smear the digits.
- Save as `.mkv` and remux to `.mp4`. Use a constant frame rate; do not enable variable frame rate.
- Name each file `<clip>_<hero>_t<n>.mp4` (for example `A2_haze_t1.mp4`) and record **at least 3 trials** per clip.

**In-game settings**:
- Keep the resolution, HUD scale and console font the same for every recording. Glyph templates and the ROI are
  tied to that combination, so any change means recalibrating (step 3).
- The game fps should be at least the recording fps.
- Keep the overlay area over a dark, plain background if you can. OCR works best there (see Limitations).

**Console commands**. The confidence levels are copied from `specs/_measurement_protocol.md`. Do not rely on
an unverified command without checking it first.

| Purpose | Command | Verified? |
|---|---|---|
| Private lobby | Play menu, custom/private lobby. The `private_lobby_create` command is also reported | UI: high. Command: **unverified** |
| Map | `map dl_midtown` | medium |
| Cheats (private only) | `sv_cheats true` | medium |
| Sandbox menu | `citadel_hero_testing_enabled 1` | medium |
| Hero | `selecthero <internal_name>` (`dump_hero_names` lists them) | medium |
| **Position and velocity overlay** | `cl_showpos 1` | medium |
| Read or set position | `getpos` / `setpos x y z` | low |
| No death | `citadel_enable_no_hero_death` | medium |
| Stamina for repeated trials | `citadel_enable_fast_stamina`. Turn it off for any stamina-timing clip | medium |
| Move speed scale | `citadel_player_move_speed_scale`. **Must stay at 1.0** | medium |
| Clean HUD | `citadel_hud_visible 0`. Whether `cl_showpos` stays visible with it is **unverified**, so check before relying on it | medium |
| Wall-detection debug | `citadel_wall_detection_debug 1` (useful for W1 wall choice) | low |
| Pause | `citadel_pause` | medium |
| Fly, to set up | `noclip`. Turn it off before the trial | medium |
| Game speed | `host_timescale`. **Never while recording a timed clip** | low–medium |
| FPS / net graph | `cl_showfps`, `cq_netgraph` | **unverified** |

**Clips** used by the example scenarios:
- **A2**: on flat ground, facing along a straight line, run a ground dash, then jump during the dash (a dash-jump),
  then air dash while still in the air, moving forward the whole time. Scenario: `scenarios/air_dash_after_dash_jump.json`.
- **W1**: run at a flat wall at a shallow angle, jump into it, then wall jump with **no movement key held**
  (a neutral kick). Scenario: `scenarios/wall_jump_neutral.json`.

## 3. Calibrate the readout ROI

```
.venv\Scripts\python.exe extract.py calibrate rec\A2_haze_t1.mp4 --out out\A2_roi.json
```

- Without `--roi`, RapidOCR finds the `pos:`/`vel:` lines on a few frames and saves the box.
- Check the saved `*_preview.png` and the crop images next to the JSON.
- If the box is wrong, give it yourself with `--roi x,y,w,h` (video pixels).
- The ROI JSON can be reused for every recording made with the same resolution and HUD settings.

## 4. Extract

**RapidOCR** needs no training. It is slower (about 15 frames/s) and is fine for short clips:

```
.venv\Scripts\python.exe extract.py extract rec\A2_haze_t1.mp4 --roi out\A2_roi.json --out out\A2_haze_t1.csv
```

**Templates** are faster and more consistent once trained for your font and HUD scale:

```
.venv\Scripts\python.exe extract.py label-dump rec\A2_haze_t1.mp4 --roi out\A2_roi.json --frames 30,200,410,600 --out out\labels_A2.json
    (open out\labels_A2.json and correct each "lines" entry to exactly what its crop PNG shows;
     the chosen frames together must contain every digit 0-9, '.', '-')
.venv\Scripts\python.exe extract.py train-templates --labels out\labels_A2.json --out out\glyphs.npz
.venv\Scripts\python.exe extract.py extract rec\A2_haze_t1.mp4 --roi out\A2_roi.json --backend template --templates out\glyphs.npz --out out\A2_haze_t1.csv --debug-dir out\A2_fail
```

**Output CSV columns**: `frame,t,pos_x,pos_y,pos_z,vel_x,vel_y,vel_z,speed_h,speed_v,vel_scalar,vel_*_derived,ang_pitch,ang_yaw,ang_roll,vel_source,dup,valid,flags`

- Units are Source-style: z-up, units and units/s (1 u = 0.0254 m).
- `valid=0` rows are kept in the file but ignored by the fitter. These are rows that failed to parse, repeated
  frames (`dup`), or outliers (a Hampel filter plus absolute tolerances `--tol-pos/--tol-vel`).
- `t` is always strictly increasing and comes from the frame index and fps (`--time-source msec` uses container
  timestamps instead).
- If the overlay shows only a scalar speed, horizontal and vertical velocity are derived from position
  (`vel_source=derived`). That is noisier, so prefer a vector readout.

Look at the printed summary: valid fraction, duplicates and rejected outliers. Before fitting, open the CSV and
scan the rows around the event.

## 5. Scenario

A scenario JSON describes a clip for the sim. Copy an example and adjust it.

- `start`: the position, yaw, velocity and stamina before the event. `geometry` holds the wall or box for W1-type clips.
- `ticks`: the number of 64 Hz ticks to simulate.
- `timeline`: the input per tick range (`from`, `to`, `buttons`, `move`, `yaw_deg`). **Set these by hand to match
  what you pressed in the video.** Step through it frame by frame. At 64 Hz one tick is 15.6 ms.
- `align`: how video time maps to sim time.
  - `threshold` (the default) matches the first crossing of a channel through `value_u`, for example the speed
    jump of the dash.
  - `manual` takes `measured_t0` (the video time of sim tick 0) with an optional `search_ticks` search.
  - `ref_window` sets the heading used for the `h_along`/`h_across` channels.
- `fit_window` and `weights`: which part of the clip counts, and how much each channel (`speed_h, vel_v, pos_h,
  pos_v, h_along, h_across`) matters. Every channel is independent of map orientation.
- `params`: the free parameters, each with `min/max/init`.
  - Mark ones that may not exist in the current build `optional`; they are skipped with a warning if missing.
  - Link them to their gap id (`gap`) from the research notes.
  - **Bounds must be generous.** A result that ends up AT BOUND means the bounds or the model are wrong. It is not a finding.

## 6. Fit

```
"D:\PortablePrograms\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64_console.exe" --headless ^
  --path "C:\Godot Projects\deadlock_like\deadlock_like" -s res://tools_fit/fit_runner.gd -- ^
  --scenario=res://tools/movement_capture/scenarios/air_dash_after_dash_jump.json ^
  --measured="C:/Godot Projects/deadlock_like/deadlock_like/tools/movement_capture/out/A2_haze_t1.csv" ^
  --out="C:/Godot Projects/deadlock_like/deadlock_like/tools/movement_capture/out/fit_A2_t1"
```

- The optional `--init=<previous best_params.json>` starts from another trial's result.
- Output goes to `--out`:
  - `best_params.json`
  - `residuals.csv`, with measured and sim values per sample
  - `sim_best_trace.csv`
  - `report.md`, which contains the params table, RMSE before and after per channel, AT BOUND and FLAT flags,
    warnings, and candidate .tres lines
- The exit code is 0 on success.
- `fit_runner` **never writes .tres files**.

The fitter's self-test builds "recordings" from the sim with known values and checks that they are recovered.
Clean data must come back within 1%, and 60 fps data with noise, rounding and dropped rows within 3%.

```
...console.exe --headless --path "C:\Godot Projects\deadlock_like\deadlock_like" -s res://tools_fit/fit_selftest.gd
```

It covers all eight session-1 scenarios (A1, A2, A3, W1, W1b, D3, D1, S2). To check a timeline you edited for a trial,
print the sim trace (locomotion changes and speeds per tick):

```
...console.exe --headless --path "C:\Godot Projects\deadlock_like\deadlock_like" -s res://tools_fit/scenario_probe.gd -- --scenario=res://tools/movement_capture/scenarios/slide_hop_chain.json --every=8
```

## 7. Review, then apply by hand

Before any number goes into a `.tres`, check all of the following:

1. Fit **every trial** (at least 3). The values should agree within a few percent. If they don't, look at the
   timeline and alignment before believing any of them.
2. `report.md`: the RMSE after the fit should be close to the overlay noise (a few u/s).
   - **AT BOUND**: widen the bounds or rethink the model.
   - **FLAT**: the clip does not constrain that parameter. Do not apply it from this clip; design a clip that
     isolates it instead.
3. Plot or scan `residuals.csv` around the event. A systematic residual shape means the model is missing
   behavior. **Do not hide it with a new cap or clamp**; write it up as a gap with the evidence.
4. Apply the value by hand to the hero/movement `.tres`. Put a provisional comment above it that names the gap,
   the clip, the trials and the spread, for example:

   ```
   # PROVISIONAL (G01): fitted from A2_haze_t1..t3 (cl_showpos video), spread 1.8 %, pending more heroes
   ```

   Then run the full test suite (`-s res://tests/run_tests.gd`). Update the spec and gap notes with the evidence.
   Only clear the PROVISIONAL mark once the value has been confirmed on independent clips.

## Limitations

- **The overlay format is unverified.** `layouts/showpos_default.json` assumes lines like `pos: x y z` and
  `vel: x y z` (or a single speed).
  - Check it against your first recording.
  - A different format only needs a layout change (`names`, `alt_names`, `full_regex`, `line_index`). No code
    change is required.
- **OCR uses fixed thresholding.** It can fail over bright or busy backgrounds. Record against dark scenery, and
  check `valid` and `--debug-dir`.
- The overlay shows **render-interpolated** values, not physics-tick values. The fitter samples the sim the same
  way (linear between ticks), but sub-tick timing is only good to about 1 ms.
- Timeline ticks (when you pressed dash or jump) are set by hand. A wrong tick biases the fit more than OCR noise does.
- Scalar-velocity overlays give velocity derived from position, which is noisier around sharp events.
- Optional parameters missing from the build are skipped with a warning.
- `air_dash_end_drag_frac` is only identifiable when the post-dash speed stays above the drag floor
  (`air_dash_end_drag_floor`). When the floor clips it, the report flags it FLAT; do not apply it from that clip.
- Fitting assumes the sim's structure is right and only tunes values. A consistently bad fit means the
  behavior differs, not that the numbers do.
- Godot prints Jolt "RID leak" messages at exit in headless runs. They are harmless.

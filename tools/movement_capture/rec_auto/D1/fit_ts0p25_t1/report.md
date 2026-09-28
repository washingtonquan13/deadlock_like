# Fit report: Ground dash speed profile (D1)

- Scenario: `res://tools/movement_capture/scenarios/ground_dash_profile.json`
- Measured: `C:/Godot Projects/deadlock_like/deadlock_like/tools/movement_capture/rec_auto/D1/val_ts0p25_t1.csv`
- Clip: D1. Gaps: G19, G22, G23
- Optimizer: nelder_mead, 301 sim runs, 3.1 s. Measured time of tick 0: 0.1079 s
- Samples in the fit window: 406. Cost 151.766 -> 143.51

Nothing here has been applied. The values below are candidates for review (plan step 3).

## Parameters

| parameter | gap | default | init | best | bounds | flags |
|---|---|---|---|---|---|---|
| ground_dash_durations[0] | G19 | 0.620000 | 0.620000 | **0.546876** | [0.400000, 0.900000] | FLAT: this clip barely constrains it |
| ground_dash_distance | G19 | 10.000000 | 10.000000 | **10.905210** | [6.000000, 14.000000] | FLAT: this clip barely constrains it |

## Fit quality (RMSE, u/s for velocities, u for positions)

| channel | weight | before | after |
|---|---|---|---|
| speed_h | 1.000000 | 483.36 | 470.92 |
| vel_v | 1.000000 | 6.20 | 6.07 |
| pos_h | 1.000000 | 39.47 | 25.33 |
| pos_v | 0.000000 | 0.55 | 0.54 |
| speed_3d | 0.000000 | 158.82 | 192.57 |

Sensitivity is the relative cost rise for a 2 % of range step from the best value. Below 0.01 means the
clip does not pin the parameter down: fix it from another clip, or add a channel that sees it.

Review `residuals.csv` (per sample: measured, sim, residual) and `sim_best_trace.csv`. A residual with
structure (a step, a slope) means a behavior difference that parameter values cannot fix. Log that as a
gap instead of forcing the fit.

## Candidate .tres lines (do not apply until reviewed across trials)

```
ground_dash_durations[0] = 0.546876   # movement_params.tres. Comment in movement_params.gd: # PROVISIONAL (G19): fitted from clip D1, pending trials
ground_dash_distance = 10.905210   # movement_params.tres. Comment in movement_params.gd: # PROVISIONAL (G19): fitted from clip D1, pending trials
```

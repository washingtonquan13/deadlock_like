# Fit report: Ground dash speed profile (D1)

- Scenario: `C:/Users/QUANWA~1/AppData/Local/Temp/nc_wlong.json`
- Measured: `C:/Godot Projects/deadlock_like/deadlock_like/tools/movement_capture/rec_auto/D1_wlong/probe_ts0p25_t1.csv`
- Clip: D1_wlong. Gaps: G19, G22, G23
- Optimizer: nelder_mead, 231 sim runs, 4.4 s. Measured time of tick 0: 0.0289 s
- Samples in the fit window: 684. Cost 39.9379 -> 39.9341

Nothing here has been applied. The values below are candidates for review (plan step 3).

## Parameters

| parameter | gap | default | init | best | bounds | flags |
|---|---|---|---|---|---|---|
| ground_dash_durations[0] | G19 | 0.620000 | 0.620000 | **0.616750** | [0.400000, 0.900000] | FLAT: this clip barely constrains it |
| ground_dash_distance | G19 | 10.000000 | 10.000000 | **9.982405** | [6.000000, 14.000000] | FLAT: this clip barely constrains it |

## Fit quality (RMSE, u/s for velocities, u for positions)

| channel | weight | before | after |
|---|---|---|---|
| speed_h | 1.000000 | 242.01 | 241.98 |
| vel_v | 1.000000 | 5.63 | 5.63 |
| pos_h | 0.000000 | 35.13 | 35.48 |
| pos_v | 0.000000 | 0.74 | 0.74 |
| speed_3d | 1.000000 | 57.49 | 57.56 |

Sensitivity is the relative cost rise for a 2 % of range step from the best value. Below 0.01 means the
clip does not pin the parameter down: fix it from another clip, or add a channel that sees it.

Review `residuals.csv` (per sample: measured, sim, residual) and `sim_best_trace.csv`. A residual with
structure (a step, a slope) means a behavior difference that parameter values cannot fix. Log that as a
gap instead of forcing the fit.

## Candidate .tres lines (do not apply until reviewed across trials)

```
ground_dash_durations[0] = 0.616750   # movement_params.tres. Comment in movement_params.gd: # PROVISIONAL (G19): fitted from clip D1_wlong, pending trials
ground_dash_distance = 9.982405   # movement_params.tres. Comment in movement_params.gd: # PROVISIONAL (G19): fitted from clip D1_wlong, pending trials
```

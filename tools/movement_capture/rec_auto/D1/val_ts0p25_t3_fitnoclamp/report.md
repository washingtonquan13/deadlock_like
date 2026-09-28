# Fit report: Ground dash speed profile (D1)

- Scenario: `C:/Users/QUANWA~1/AppData/Local/Temp/nc_D1.json`
- Measured: `C:/Godot Projects/deadlock_like/deadlock_like/tools/movement_capture/rec_auto/D1/val_ts0p25_t3.csv`
- Clip: D1. Gaps: G19, G22, G23
- Optimizer: nelder_mead, 221 sim runs, 2.1 s. Measured time of tick 0: 0.0259 s
- Samples in the fit window: 463. Cost 0.175708 -> 0.0746408

Nothing here has been applied. The values below are candidates for review (plan step 3).

## Parameters

| parameter | gap | default | init | best | bounds | flags |
|---|---|---|---|---|---|---|
| ground_dash_durations[0] | G19 | 0.620000 | 0.620000 | **0.602683** | [0.400000, 0.900000] |  |
| ground_dash_distance | G19 | 10.000000 | 10.000000 | **9.717659** | [6.000000, 14.000000] |  |

## Fit quality (RMSE, u/s for velocities, u for positions)

| channel | weight | before | after |
|---|---|---|---|
| speed_h | 0.000000 | 408.90 | 409.01 |
| vel_v | 0.000000 | 7.46 | 7.46 |
| pos_h | 0.000000 | 34.66 | 34.65 |
| pos_v | 0.000000 | 0.77 | 0.77 |
| speed_3d | 1.000000 | 16.50 | 10.76 |

Sensitivity is the relative cost rise for a 2 % of range step from the best value. Below 0.01 means the
clip does not pin the parameter down: fix it from another clip, or add a channel that sees it.

Review `residuals.csv` (per sample: measured, sim, residual) and `sim_best_trace.csv`. A residual with
structure (a step, a slope) means a behavior difference that parameter values cannot fix. Log that as a
gap instead of forcing the fit.

## Candidate .tres lines (do not apply until reviewed across trials)

```
ground_dash_durations[0] = 0.602683   # movement_params.tres. Comment in movement_params.gd: # PROVISIONAL (G19): fitted from clip D1, pending trials
ground_dash_distance = 9.717659   # movement_params.tres. Comment in movement_params.gd: # PROVISIONAL (G19): fitted from clip D1, pending trials
```

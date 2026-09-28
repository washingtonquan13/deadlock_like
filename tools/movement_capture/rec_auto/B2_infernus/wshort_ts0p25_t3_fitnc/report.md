# Fit report: Ground dash speed profile (D1)

- Scenario: `C:\Users\QUANWA~1\AppData\Local\Temp/nc_b2.json`
- Measured: `tools/movement_capture/rec_auto/B2_infernus/wshort_ts0p25_t3.csv`
- Clip: B2_infernus. Gaps: G19, G22, G23
- Optimizer: nelder_mead, 208 sim runs, 2.5 s. Measured time of tick 0: 0.0265 s
- Samples in the fit window: 495. Cost 0.125642 -> 0.0265142

Nothing here has been applied. The values below are candidates for review (plan step 3).

## Parameters

| parameter | gap | default | init | best | bounds | flags |
|---|---|---|---|---|---|---|
| ground_dash_durations[1] | G19 | 0.680000 | 0.680000 | **0.668185** | [0.400000, 0.900000] |  |
| ground_dash_distance | G19 | 10.000000 | 10.000000 | **9.816624** | [6.000000, 14.000000] |  |

## Fit quality (RMSE, u/s for velocities, u for positions)

| channel | weight | before | after |
|---|---|---|---|
| speed_h | 0.000000 | 419.51 | 419.77 |
| vel_v | 0.000000 | 5.93 | 5.93 |
| pos_h | 0.000000 | 30.57 | 30.49 |
| pos_v | 0.000000 | 0.59 | 0.59 |
| speed_3d | 1.000000 | 13.96 | 6.41 |

Sensitivity is the relative cost rise for a 2 % of range step from the best value. Below 0.01 means the
clip does not pin the parameter down: fix it from another clip, or add a channel that sees it.

Review `residuals.csv` (per sample: measured, sim, residual) and `sim_best_trace.csv`. A residual with
structure (a step, a slope) means a behavior difference that parameter values cannot fix. Log that as a
gap instead of forcing the fit.

## Candidate .tres lines (do not apply until reviewed across trials)

```
ground_dash_durations[1] = 0.668185   # movement_params.tres. Comment in movement_params.gd: # PROVISIONAL (G19): fitted from clip B2_infernus, pending trials
ground_dash_distance = 9.816624   # movement_params.tres. Comment in movement_params.gd: # PROVISIONAL (G19): fitted from clip B2_infernus, pending trials
```

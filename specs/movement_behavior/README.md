# Movement behavior specs (clean-room)

These are verified or sourced descriptions of how Deadlock movement behaves, compiled only from public sources and our own private-lobby observation. No game files, memory or traffic are used.
The confidence letters are H, M and L. Numbers flagged "Rec" are waiting on a recording.

## Behavior specs

| File | Covers |
|---|---|
| [ground_dash.md](ground_dash.md) | Ground dash distance and duration by bucket, the velocity set, dash-jump window, lockout and speeds, dash slide, crouch storage, dash hop, bucket roster |
| [air_movement.md](air_movement.md) | Air jump, air dash impulse and directional cap, end drag, down dash, air strafe, air drag, gravity, IAD, bhop, per-airtime counters (U1–U13) |
| [walls_and_ledges.md](walls_and_ledges.md) | Wall jump (costs, fatigue, launch composition, input shaping), corner and edge boost, wall slide, mantle bands, mantle glide and superglide |
| [slide_and_slopes.md](slide_and_slopes.md) | Slide entry, friction and penalty onset, item delays, slide-hop drag flag, slopes, no ground speed cap, sprint interaction |
| [ziplines_melee_misc.md](ziplines_melee_misc.md) | Zipline speeds, boost, dismount and cake jump, knock-off, heavy melee lunge and recovery, parry, jump pads, ability movement notes |
| [tech_catalog.md](tech_catalog.md) | Consolidated list of named movement tech with pointers into the files above |

## Measurement

| File | Covers |
|---|---|
| [recording_shot_list.md](recording_shot_list.md) | Prioritized private-lobby clip list. Session A (about 40 min) covers the air-dash cap, end drag, wall-jump momentum, corner boost, dash-jump, dash profile and slide-hop. Session B covers the rest. |
| [../_measurement_protocol.md](../_measurement_protocol.md) | Ground rules, command verification levels, recipes R0–R11, CSV format |
| `data/measurements/template.csv` | Header for recorded trials |

## Related design docs

| File | Covers |
|---|---|
| [../../docs/design/movement_fidelity_gaps.md](../../docs/design/movement_fidelity_gaps.md) | Code vs real behavior, gap by gap (G01–G48): every cap, clamp and reset in `src/movement` marked supported, contradicted or unknown, plus missing behaviors and the top 10 by feel impact |
| [../../docs/design/movement_architecture.md](../../docs/design/movement_architecture.md) | Simulation architecture |
| [../../docs/design/movement_status.md](../../docs/design/movement_status.md) | Implementation status, tests and deviations |
| [../movement.md](../movement.md) | Frozen baseline spec that the current parameters cite |

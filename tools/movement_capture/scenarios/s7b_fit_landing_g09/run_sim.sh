#!/bin/bash
# Replays the s7_open LT*/SHH* scenarios (and s6 SHH6/SHH40) in the sim. Usage: run_sim.sh TAG [--set=...]
# Writes tools_fit/_out/s7b_landing_g09/TAG_NAME.csv
G="D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
cd "C:/Godot Projects/deadlock_like/deadlock_like"
TAG=$1; shift
for S in s7_open/LT465 s7_open/LT460 s7_open/LT450 s7_open/LT440 s6_slidejump/SHH6 s7_open/SHH12 s7_open/SHH20 s7_open/SHH30 s6_slidejump/SHH40 s7_open/SHH6F; do
  N=$(basename $S)
  "$G" --headless --path . -s res://tools/movement_capture/scenarios/s7b_fit_landing_g09/replay.gd -- \
    --scenario=res://tools/movement_capture/scenarios/$S.json --out=tools_fit/_out/s7b_landing_g09/${TAG}_$N.csv "$@" >/dev/null 2>&1 || echo "fail $N"
done

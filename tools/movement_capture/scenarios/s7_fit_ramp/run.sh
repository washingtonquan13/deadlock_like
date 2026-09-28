#!/bin/sh
# s7 ramp: replay the ramp scenarios in the sim. usage (from the project root): sh run.sh TAG [PATCH]
# writes tools_fit/_out/s7_ramp/TAG_<scn>.csv; PATCH e.g. s7_h=1,s7_a=1,s7_up_end=1 (see s7_patch.gd)
G="D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
TAG=$1; P=${2:+--patch=$2}
cd "/c/Godot Projects/deadlock_like/deadlock_like"
for s in RWALK RBOT RRUN RDASH RJ RSWtop; do
  "$G" --headless --path . -s res://tools/movement_capture/scenarios/s7_fit_ramp/ramp_replay.gd -- \
    --scenario=res://tools/movement_capture/scenarios/s7_ramp/$s.json --out=tools_fit/_out/s7_ramp/${TAG}_$s.csv $P 2>&1 | grep -i "error\|snap\|patch" | head -5
done
"$G" --headless --path . -s res://tools/movement_capture/scenarios/s7_fit_ramp/ramp_replay.gd -- \
  --scenario=res://tools/movement_capture/scenarios/s7_ramp/RUP.json --start=bot --out=tools_fit/_out/s7_ramp/${TAG}_RUP.csv $P 2>&1 | grep -i "error\|snap" | head -5

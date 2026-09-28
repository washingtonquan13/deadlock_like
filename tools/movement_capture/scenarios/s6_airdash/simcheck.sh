#!/bin/bash
# usage (from the project root): bash tools/movement_capture/scenarios/s6_airdash/simcheck.sh [NAME...]
# replays each scenario in the sim (route_export) and prints extents, jump/dash states and the air-dash peak
G="D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
D=tools/movement_capture/scenarios/s6_airdash
N="$@"; [ -z "$N" ] && N=$(cd $D && ls E*.json | sed 's/.json//')
mkdir -p tools_fit/_out
for S in $N; do
  "$G" --headless --path . -s res://tools_fit/route_export.gd -- --scenario=res://$D/$S.json --out=tools_fit/_out/s6_$S.csv > tools_fit/_out/s6_$S.log 2>&1
  rc=$?; errs=$(grep -ciE "error|route_export:" tools_fit/_out/s6_$S.log)
  echo "== $S rc=$rc error_lines=$errs"
  tools/movement_capture/.venv/Scripts/python.exe $D/simsum.py tools_fit/_out/s6_$S.csv
done

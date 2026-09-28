#!/bin/bash
# usage (project root): bash tools/movement_capture/scenarios/s6_adfit/runall.sh TAG  -> tools_fit/_out/adfit_TAG_<name>.csv
G="D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
TAG=${1:-cur}
for J in tools/movement_capture/scenarios/s6_airdash/E*.json tools/movement_capture/scenarios/s6_adfit/A_*.json; do
  S=$(basename $J .json)
  "$G" --headless --path . -s res://tools_fit/route_export.gd -- --scenario=res://$J --out=tools_fit/_out/adfit_${TAG}_$S.csv > /dev/null 2>&1 || echo "FAIL $S"
done

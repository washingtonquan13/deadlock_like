#!/bin/bash
# usage (from the project root): simrun.sh NAME  -> scenarios/route/NAME_sim.csv
G="D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
"$G" --headless --path . -s res://tools_fit/route_export.gd -- --scenario=res://tools/movement_capture/scenarios/route/$1.json --out=tools/movement_capture/scenarios/route/$1_sim.csv 2>&1 | grep -iE "error|route_export"
awk -F, 'NR>1 && (NR-2)%20==0 {printf "%s f%.0f l%.0f z%.0f v%.0f %s\n",$1,$2,$3,$4,$5,$8}' tools/movement_capture/scenarios/route/$1_sim.csv | paste - - - | column -t

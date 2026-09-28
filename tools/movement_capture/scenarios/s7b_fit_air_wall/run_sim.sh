#!/bin/bash
# Replays every generated scenario in this folder with route_export. Run from anywhere.
ROOT="C:/Godot Projects/deadlock_like/deadlock_like"; G="D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
cd "$ROOT"; mkdir -p tools_fit/_out/s7b_air_wall
for f in tools/movement_capture/scenarios/s7b_fit_air_wall/*_{cur,prop,prop105}.json; do
  n=$(basename "$f" .json)
  "$G" --headless --path . -s res://tools_fit/route_export.gd -- --scenario=res://$f --out=tools_fit/_out/s7b_air_wall/$n.csv 2>&1 | grep -i "error" | head -3
done

#!/bin/sh
# replay the s7_open SE* scenarios in the sim (flat). usage from the project root: sh run_sim.sh TAG [SETS] [ONSET0]
# SETS e.g. slide_entry_speed=9.0; ONSET0 overrides slide_onset_table[0] (s). Scratch overrides via se_replay.gd, never src.
G="D:/PortablePrograms/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe"
TAG=$1; S=""; O=""
[ -n "$2" ] && S="--set=$2"
[ -n "$3" ] && O="--onset0=$3"
cd "/c/Godot Projects/deadlock_like/deadlock_like"
for s in SEPROBE SE300 SE320 SE330 SE333 SE336 SE340 SE360; do
  "$G" --headless --path . -s res://tools/movement_capture/scenarios/s7b_fit_slide_entry/se_replay.gd -- \
    --scenario=res://tools/movement_capture/scenarios/s7_open/$s.json --out=tools_fit/_out/s7b_slide_entry/${TAG}_$s.csv $S $O 2>&1 | grep -i "error\|set " | head -3
done

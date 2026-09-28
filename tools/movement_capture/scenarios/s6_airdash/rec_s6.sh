#!/bin/bash
# usage (from tools/movement_capture): bash scenarios/s6_airdash/rec_s6.sh [NAME...]   (default: all 8)
# Records each scenario at host_timescale 0.25 on mark street_y148 (Haze), one trial per driver call with a rest
# in between so both stamina charges (ground dash + air dash, 4.5 s each, sequential) are back before every trial.
# env: TRIALS (default 3), REST (real seconds at timescale 1 before each trial, default 11), TAIL (default 1.5)
PY=".venv/Scripts/python.exe"; D=scenarios/s6_airdash
N="$@"; [ -z "$N" ] && N="E200W E386W E386S E386WD E520W E700W E700S E700WD"
focus() { "$PY" -c "import sys;sys.path.insert(0,'driver');import gameio;sys.exit(0 if gameio.focus_game(verbose=True) else 1)"; }
for S in $N; do
  for i in $(seq 1 ${TRIALS:-3}); do
    sleep ${REST:-11}
    focus
    run() { "$PY" driver/driver.py run $D/$S.json --mark street_y148 --trials 1 --timescale 0.25 --tag t$i --tail ${TAIL:-1.5} --out rec_auto/s6_airdash/$S 2>&1 | tail -1; }
    out=$(run); echo "$S t$i: $out"
    if echo "$out" | grep -q "STOPPED: the game is not in front"; then sleep ${REST:-11}; focus && { out=$(run); echo "$S t$i retry: $out"; }; fi
  done
  "$PY" driver/driver.py extract rec_auto/s6_airdash/$S >/dev/null 2>&1
done
"$PY" $D/existing.py "rec_auto/s6_airdash/*/*.csv"

#!/bin/bash
# usage: rec.sh MARK TRIALS SCEN...   (run from tools/movement_capture) records, extracts, analyses
# env: DIR (scenario folder, default wall), TAIL (s recorded after the last input), STEP (analysis table step)
PY=".venv/Scripts/python.exe"; M=$1; N=$2; shift 2
focus() { "$PY" -c "import sys;sys.path.insert(0,'driver');import gameio;sys.exit(0 if gameio.focus_game(verbose=True) else 1)"; }
for S in "$@"; do
  focus
  run() { "$PY" driver/driver.py run scenarios/${DIR:-wall}/$S.json --mark $M --trials $N --tail ${TAIL:-1.0} --out rec_auto/${DIR:-wall}/$S 2>&1 | tail -1; }
  out=$(run); echo "$out"
  # the game lost focus mid-set (textinputhost steals it): refocus and retry once
  if echo "$out" | grep -q "STOPPED: the game is not in front"; then focus && { out=$(run); echo "$out"; }; fi
  "$PY" driver/driver.py extract rec_auto/${DIR:-wall}/$S >/dev/null 2>&1
  MARK=$M "$PY" scenarios/wall/analyze.py rec_auto/${DIR:-wall}/$S ${STEP:-0.25}
done

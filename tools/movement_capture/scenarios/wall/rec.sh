#!/bin/bash
# usage: rec.sh MARK TRIALS SCEN...   (run from tools/movement_capture) records, extracts, analyses
PY=".venv/Scripts/python.exe"; M=$1; N=$2; shift 2
for S in "$@"; do
  "$PY" -c "import sys;sys.path.insert(0,'driver');import gameio;gameio.focus_game()"
  "$PY" driver/driver.py run scenarios/wall/$S.json --mark $M --trials $N --out rec_auto/wall/$S 2>&1 | tail -1
  "$PY" driver/driver.py extract rec_auto/wall/$S >/dev/null 2>&1
  MARK=$M "$PY" scenarios/wall/analyze.py rec_auto/wall/$S ${STEP:-0.25}
done

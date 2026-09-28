#!/bin/bash
# usage (from tools/movement_capture): bash scenarios/s11_conf/rec.sh MARK TRIALS SCEN...  kills lane minions before each scenario
M=$1; N=$2; shift 2
for S in "$@"; do .venv/Scripts/python.exe scenarios/s9_open/kill.py; DIR=s11_conf bash scenarios/rec.sh $M $N $S; done

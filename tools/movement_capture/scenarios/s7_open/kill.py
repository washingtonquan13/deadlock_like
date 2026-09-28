"""Sends trooper_kill_all (lane minions hit and slow the hero). Run from tools/movement_capture."""
import sys; sys.path.insert(0, "driver")
import gameio as g
g.focus_game(); g.console(["trooper_kill_all"])

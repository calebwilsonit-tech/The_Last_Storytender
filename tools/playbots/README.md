# Playbots

Scripts that play a dungeon with the real controls (move, echo, interact) and live enemies, and print what happened.
Run from the repo root (needs a display; `xvfb-run` works):

    OUT=/tmp/shot xvfb-run -a godot --path . --fixed-fps 60 -s tools/playbots/weighing.gd --rendering-driver opengl3

Rule for this project: play a new or rebuilt dungeon with a bot (or by hand) before pushing it.

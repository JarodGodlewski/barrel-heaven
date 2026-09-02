---
description: Run Barrel Heaven Godot loadout + combat smoke tests.
agent: build
---

Run both smokes from `godot/` using `tools\Godot_v4.7-stable_win64_console.exe`.

1. `--headless --path . --script res://tools/smoke_loadout.gd`
2. `--headless --path . -- --smoke`

Report the `GAME SMOKE OK` line (kills, types, boss, won) or the first error. Do not edit files unless a test fails and the user asked to fix it. Extra args: $ARGUMENTS

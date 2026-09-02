---
name: godot-smoke
description: Use when verifying Barrel Heaven after gameplay changes, or when the user says smoke, headless, GAME SMOKE OK, or screenshot. Runs Godot 4.7 portable console from godot/tools.
---

# Godot smoke

CWD: `godot/`. Binary: `tools\Godot_v4.7-stable_win64_console.exe`.

Loadout:

```
tools\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/smoke_loadout.gd
```

Combat (8× time scale, compressed boss clock):

```
tools\Godot_v4.7-stable_win64_console.exe --headless --path . -- --smoke
```

Shot:

```
tools\Godot_v4.7-stable_win64_console.exe --path . -- --shot
```

PNG lands in `%APPDATA%\Godot\app_userdata\Barrel Heaven\shot.png`.

Pass: stdout contains `GAME SMOKE OK`. Fail: stop and fix; do not continue extraction.

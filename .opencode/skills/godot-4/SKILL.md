---
name: godot-4
description: Use when writing or reviewing Barrel Heaven GDScript, scenes, shaders, pooling, cameras, or Godot 4.7 pitfalls. Not for lore or design essays.
---

# Godot 4.7 — this cart

Engine: **4.7 stable**, GDScript, **GL Compatibility**. Project: `godot/`.

## MCP vs this skill

Godot MCP: launch, run, debug output, scenes/nodes. It does **not** know API taste.
Official docs: https://docs.godotengine.org/en/4.7/ — fetch a **specific** class page, don't scrape the whole manual.

## Hard rules here

- Tabs. snake_case. No comments unless Jarod asks.
- Gameplay numbers: constants or `.tres`, not magic in `_process`.
- **No** `instantiate()` / `queue_free()` in `_process`. Pool (`ObjectPool`) or hide/show.
- Systems are **children of Main**, not new autoloads. Autoloads: Storage, Settings, AudioManager, GameState, EventBus, QaWatch.
- `class_name` is fine in-editor; headless `--script` may not see it. Prefer `preload("res://...")` for Catalog/Pool.
- Don't grow `main.gd`. Put new toys in `src/core/systems/`.

## GDScript 4.7

- Type what you can: `var x: float`, `Array`, `Dictionary`. If inference fails (`:=` on Variant), write `: float =`.
- `Input.get_axis("left","right")` — check `project.godot` names.
- Euler on Node3D is `rotation`; don't mix `transform.basis` unless you mean it.
- `look_at` fails if target == camera pos — guard `length_squared()`.
- Signals: emit on EventBus for cross-system; UI may read GameState.
- Tweens: `create_tween()` on the node that owns the property; kill on reset if needed.
- `Engine.time_scale` is smoke-only. Feel uses `hitstop` on `dt`, not global scale.

## 3D / Compatibility

- No renderer features that need Forward+. Particles: **CPUParticles3D**.
- Unshaded + additive for bolts/streaks. Vertex colors for ship/enemy palette shaders.
- Camera child streaks = local space. Don't parent world VFX to the camera unless local_coords is intended.
- `VisibleOnScreenNotifier3D` later for culling; not on player/boss.

## UI

- HUD is `CanvasLayer` (`ui.gd`). Don't put Control under Node3D without a layer.
- Pause / level-up: **stop sim**, don't keep yawing the ship.
- Safe area: intersect with window rect before offsets.

## Feel (code)

- Clamp `dt` (`minf(delta, 0.05)`).
- Stick: slew then apply (`lerpf` toward axis), don't raw-snap yaw.
- I-frames = roll window, not a gift.
- Juice = flash + short hitstop + sfx. Not a new cutscene.

## Verify

From `godot/`:

```
tools\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/smoke_loadout.gd
tools\Godot_v4.7-stable_win64_console.exe --headless --path . -- --smoke
```

Play logs: `%APPDATA%\Godot\app_userdata\Barrel Heaven\logs\godot.log`

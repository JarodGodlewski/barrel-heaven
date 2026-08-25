# Barrel Heaven — Godot

Star Fox all-range x Vampire Survivors horde. Birddog Softworks demo.

Ported from the Three.js MVP in `../js/` (kept as design reference).

## Quick start

1. Open this folder in **Godot 4.3** (or run `tools/Godot_v4.3-stable_win64.exe`)
2. Import `project.godot`
3. Main scene lands Week 2 — until then use the smoke test:

```
tools\Godot_v4.3-stable_win64_console.exe --headless --path . --script res://tools/smoke_loadout.gd
```

## Layout

```
project.godot            autoloads, input map (KB/gamepad), GL Compatibility
default_bus_layout.tres  Master / Music / SFX / Voice buses
src/autoloads/           Storage, Settings, AudioManager, GameState
src/core/loadout.gd      weapons/passives/evolutions (port of js/loadout.js)
src/ui/                  HUD, LevelUp draft, Comms, Radar, Overlay (Week 2-3)
scenes/                  Main.tscn + pooled entities (Week 2)
assets/shaders/          ship / enemy / bolt / sky (programmer-art pipeline)
tools/                   smoke tests + portable Godot binary (not committed)
addons/                  GodotSteam lands Week 5
```

## Conventions

- GDScript, tabs, snake_case files matching scene names
- All gameplay numbers live in constants at the top of the owning script
- Pool everything that spawns per-frame; no `instantiate()` in `_process()`
- Platform-specific code goes behind autoloads, never into gameplay scripts
- Ship meshes must set vertex colors for the palette shader (R=engine, G=secondary, B=trim)

## Locked demo scope

One sector ("The Well"), one ship, one boss (~8:00-10:00 Mercy jump),
10:00 survival win. 6 weapons + evolutions, 6 passives, level-up draft,
field caches, wingman comms (placeholder TTS). No meta progression.

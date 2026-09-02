# Barrel Heaven — agent instructions

Star Fox all-range × Vampire Survivors. Publisher: Birddog Softworks.
Engine: **Godot 4.7 stable**, GDScript, GL Compatibility.
Playable project: `godot/` (Three.js MVP in `js/` is design reference only).

Human: **Jarod**. Address him as Jarod.

## Inference policy

Use **xAI** (primary) and **local Ollama** only. No OpenRouter, OpenAI, Anthropic, Gemini, or Zen.

| Role | Model |
|------|--------|
| Build / plan / architecture | `xai/grok-4.6` |
| Titles, compression, cheap explore | `ollama/qwen3:32b` or `ollama/qwen2.5:32b` |
| Heavy local fallback | `ollama/qwen2.5:72b` |

Ollama is at `http://127.0.0.1:11434`. Installed: `qwen3:32b`, `qwen2.5:72b`, `qwen2.5:32b`, `llama3.1`.

## Layout

```
godot/project.godot          autoloads, input map, GL Compatibility
godot/src/autoloads/         Storage, Settings, AudioManager, GameState
godot/src/core/main.gd       run loop (too large — extract, don't grow)
godot/src/core/loadout.gd    weapons / passives / evolutions
godot/src/core/boss.gd       Guardian (arms then core)
godot/src/ui/ui.gd           HUD, radar, comms, overlays, pause
godot/assets/shaders/        ship, enemy, bolt, sky, grid
godot/tools/                 portable Godot 4.7 + smoke scripts
docs/ARCHITECTURE.md         extraction plan (composition + .tres + EventBus)
docs/LEVEL1.md               locked demo scope
```

Autoloads: `Storage`, `Settings`, `AudioManager`, `GameState`.

## Conventions

- GDScript, tabs, snake_case. **No comments unless asked.**
- Gameplay numbers: constants at top of owning script until they move to `.tres`.
- Pool per-frame spawns. No `instantiate()` / `queue_free()` in `_process`.
- Platform code behind autoloads, never in gameplay scripts.
- Ship meshes: vertex colors for palette shader (R=engine, G=secondary, B=trim).
- Do not commit secrets, `godot/tools/Godot_v*.exe`, or `.godot/`.

## Locked demo scope

One sector (The Well), one ship, one boss ~8:00–10:00, survive 10:00 to win.
6 weapons + evolutions, 6 passives, level-up draft, caches, comms, smart bomb (Q).
Meta progression is stubbed in `GameState.meta` — do not build it until extraction is done.

Enemy types (all smoke-verified): chaser, weaver, turret, splitter, brute, mini.

## Architecture direction

`main.gd` is a god-class (~1.7k lines). Agreed extraction (see `docs/ARCHITECTURE.md`):

1. `ObjectPool` + `EventBus` autoload + `.tres` Resources (zero behavior change)
2. Systems as **child nodes of Main** (not autoloads): Spawn, Enemy, Projectile, Weapon, Pickup, World, Boss
3. Uniform grid spatial hash (8 m cells, 960 arena)
4. EventBus for cross-system only; UI may still read GameState signals
5. Then meta-progression / quality settings

Do not add a seventh enemy type or a new weapon by stuffing another `match` into `main.gd`. Put data in a Resource and behavior in the owning system.

## Godot coding

Load skill `godot-4` when writing GDScript. MCP does not replace that.
Docs: fetch a single class URL on docs.godotengine.org/en/4.7 — do not ingest the whole manual.

## Play QA

Godot writes `%APPDATA%\\Godot\\app_userdata\\Barrel Heaven\\logs\\godot.log`.
`QaWatch` autoload also writes `user://qa_errors.log`.
Tail while playing: `godot/tools/watch_play.ps1`
After a crash, read those logs before guessing.

## Verify

From `godot/`:

```
tools\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/smoke_loadout.gd
tools\Godot_v4.7-stable_win64_console.exe --headless --path . -- --smoke
```

Require `GAME SMOKE OK` (6 types, boss, win) after combat changes.

## Hermes

Birddog Softworks island (does not overwrite the LAD default profile):

```
hermes -p barrel-heaven
```

Profile home: `%LOCALAPPDATA%\hermes\profiles\barrel-heaven`
CWD: `C:/Workspace/barrel-heaven/godot`

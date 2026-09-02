---
name: barrel-heaven
description: Use when editing Barrel Heaven Godot gameplay, enemies, weapons, UI, boss, pooling, or architecture extraction. Trigger on main.gd, loadout.gd, boss.gd, ui.gd, GameState, EventBus, ObjectPool.
---

# Barrel Heaven

Read `AGENTS.md` and `docs/ARCHITECTURE.md` first.

- Work in `godot/`. GDScript, tabs, no comments unless asked.
- Do not grow `src/core/main.gd`. Extract to child systems.
- Pool spawns. EventBus for cross-system only. UI may read GameState.
- After combat edits, run smoke (see skill `godot-smoke`).
- Inference: xAI or local Ollama only.

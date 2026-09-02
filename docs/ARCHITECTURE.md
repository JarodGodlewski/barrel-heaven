# Barrel Heaven — extraction architecture

Status: **planned**. Gameplay works in the god-class. Extract before adding systems.

Decisions already locked:

- Systems are **composition** (Main owns child system nodes), not autoload singletons.
- Config is **Godot `.tres` Resources**, not JSON/CSV.
- Spatial structure is a **uniform grid** (8 m cells, arena 960).
- **EventBus is cross-system only.** UI may read `GameState` signals directly.

## Why

`godot/src/core/main.gd` (~1764 lines) owns world build, player mesh, enemy roster, pooling, weapons, projectiles, gems/pods/caches, asteroids, camera, touch, boss glue, and run flow. `ui.gd` reaches into `main.enemies` / `main.loadout`. `boss.gd` calls `main.ui`, `main.sfx`, `main.GameState`. Adding a weapon or enemy type currently means editing Main in several places.

## Phase 1 — infrastructure (no behavior change)

| Piece | Path |
|-------|------|
| Generic pool | `godot/src/core/pool.gd` |
| EventBus autoload | `godot/src/autoloads/EventBus.gd` |
| Enemy / weapon / passive / boss-pattern Resources | `godot/resources/` |
| System base | `godot/src/core/systems/system_base.gd` |

Smoke after this phase must still print `GAME SMOKE OK`.

## Phase 2 — extract systems (one at a time, smoke each)

Main children:

```
Main
├── SpawnSystem
├── EnemySystem
├── ProjectileSystem
├── WeaponSystem
├── PickupSystem
├── WorldSystem
├── BossSystem
└── PlayerController
```

Main keeps run flow, input routing, and system init. Target: Main under ~300 lines.

## Phase 3 — perf

- `SpatialHash` (`godot/src/core/spatial_hash.gd`) for separation + projectile broadphase
- `VisibleOnScreenNotifier3D` on pooled entities (not player / boss / orbiters)
- `_physics_process` for sim, `_process` for visuals
- Pool warmup from a Resource

## Phase 4 — progression (after extraction)

`UpgradeDefinition` / ship-kit Resources, `meta_progression.gd` using existing `GameState.meta` stubs. Do not start this while Main is still the god-class.

## Rollout

Pool → EventBus → Resources → SpatialHash (unit-compared to old O(n²) for 100 frames) → Spawn → Enemy → Projectile → Weapon → Pickup/World/Boss → culling/split → progression.

If smoke fails, revert the last extraction. Do not stack two extractions in one commit.

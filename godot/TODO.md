# Barrel Heaven — Autonomous Task List

> Run `git push` → CI validates. When stuck, paste CI log here. When back, say "continue" and I pick up next unchecked item.

## Week 2 — Core Combat (no art needed)

- [ ] **2.1 Main.tscn** — Replace Boot.tscn
  - WorldEnvironment with `bg_sky.gdshader` sky resource
  - Camera3D with portrait/landscape FOV logic (port from `updateCamera()`)
  - DirectionalLight + HemisphereLight matching Three.js setup

- [ ] **2.2 Player ship** — `scenes/Player.tscn` + `src/core/PlayerShip.gd`
  - Build mesh from primitives (Cone/Box/Cylinder) with vertex colors for palette shader
  - Throttle/yaw/roll/boost physics ported from `updatePlayer()` (dt-based, frame-independent)
  - Input handling: `steer_left/right`, `throttle_up/down`, `boost`, `roll`, `cut_throttle`, `uturn`
  - Barrel roll i-frames, engine pulse, damage flash via shader uniforms
  - Safe-area clamp + auto U-turn at bounds (port `confinePlayer()`)

- [ ] **2.3 Enemy base** — `scenes/Enemy.tscn` + `src/core/Enemy.gd`
  - Cone + wing mesh, `enemy.gdshader` material
  - AI: turn toward player, forward speed, wrap at arena bounds
  - HP, boss flag, drop pod on death
  - Collision: hull hit → player damage + i-frames

- [ ] **2.4 Projectile pooling** — `scenes/Projectile.tscn` + `src/core/Projectile.gd`
  - Bolt mesh (Cylinder) + `bolt.gdshader`
  - Pool arrays: pre-allocate 256, reuse on fire/expire
  - Hit detection: sphere vs enemy (radius from loadout `area` stat)

- [ ] **2.5 Weapon firing** — `src/core/WeaponSystem.gd`
  - Port `tickWeapons()`, `fireWeapon()` for all 6 types
  - Twin / Lock / Bomb (orbiters) / Nova / Scatter / Mines
  - Cooldowns scaled by loadout `cooldown` stat

- [ ] **2.6 Sector spawner** — `src/core/Sector.gd`
  - Horde scaling: `desiredHorde()` port
  - Spawn timer, ace timeline → single boss at ~480s (8:00)
  - Field caches at cardinals (patch/scoop/flare)

- [ ] **2.7 Gems + Pods + Caches** — `scenes/Gem.tscn`, `Pod.tscn`, `Cache.tscn`
  - Gem magnet pull (loadout `magnet` stat), XP on collect
  - Pod: evolves first evolvable weapon, else bonus XP
  - Cache: patch heals, scoop vacuums gems, flare clears non-boss enemies

- [ ] **2.8 Win/Lose + Boot swap**
  - `GameState.end_run()` integration
  - Main.tscn replaces Boot.tscn in project.godot

- [ ] **2.9 Android sideload test**
  - Download Godot Android export template
  - Build .apk, install via `adb`, verify touch controls work


## Week 3 — UI & Polish

- [ ] **3.1 HUD** — `src/ui/HUD.gd` + scene
  - Hull bars, kills, wave, time, level, XP bar, kit line

- [ ] **3.2 LevelUp draft** — `src/ui/LevelUp.gd` + scene
  - 3-card layout, 1/2/3 keys + tap, pauses run

- [ ] **3.3 Comms** — `src/ui/Comms.gd` + scene
  - Port blobcam to CanvasItem shader (portrait faces)
  - Dialogue queue with speaker/mood timing

- [ ] **3.4 Radar** — `src/ui/Radar.gd` + CanvasItem 2D
  - Player-centered, enemies (boss gold), caches (colored)

- [ ] **3.5 Overlay** — Start / GameOver / Win screens

- [ ] **3.6 Juice** — particles, screen shake, hit pause, engine trails


## Week 4 — Platform Exports

- [ ] **4.1 iOS** — Xcode project, SafeArea, Game Center, CoreHaptics
- [ ] **4.2 Android** — Gradle, Play Games, Adaptive Icon, 64-bit ARM
- [ ] **4.3 Steam** — GodotSteam GDExtension, achievements/leaderboards/cloud
- [ ] **4.4 Web demo** — WASM, IndexedDB saves, itch.io page
- [ ] **4.5 Steam Deck** — 1280x800 profile, gamepad-only, battery test


## Done (Week 1)

- [x] Project scaffold, autoloads, input map
- [x] Storage / Settings / AudioManager / GameState
- [x] loadout.gd port + 13 smoke checks
- [x] 4 shaders (ship/enemy/bolt/sky)
- [x] Boot.tscn runtime validation
- [x] Export preset stubs + CI workflow
- [x] Git repo + CI
# Art pipeline — Barrel Heaven

Look: **PS1 Crash, a little PS2.** Low poly (500–2k tris), vertex color, chunky silhouette. Cel paint (Bluth / Titan A.E., 2–3 bands) on top. Brass and rust. Not PBR, not mint, not Fortnite.

Shader already toons it. Drop **real GLBs** — the primitive cones are placeholders. Comms faces stay 2D.

**Budget:** Crash 1 character, not Uncharted. Affine warp is a maybe later; don't fake it in the mesh.

## Drop-in (live now)

Put a file here and restart:

| File | What |
|------|------|
| `godot/assets/meshes/rook.tscn` or `rook.glb` | Player hull. Replaces primitives. |
| later: `chaser.glb` `weaver.glb` `turret.glb` `splitter.glb` `brute.glb` `mini.glb` | Enemies (not wired yet) |

**Export:** nose **+Z**, origin center, ~**3.4 m** long, Y up. Low poly (500–2k tris). Vertex colors: **R = engine glow, G = hull, B = trim**. No metal/rough maps.

Hop / roll / bank now spin `player/visual`, not the gameplay node. When a GLB has an `AnimationPlayer`, clips we will play:

`idle` · `boost` · `roll` · `hop_rise` · `hop_hang` · `hop_land`

Until those clips exist, code still drives the flip.

## Prompt (Meshy / Tripo / Rodin / Hunyuan)

```
PS1 Crash Bandicoot low poly spaceship, Don Bluth Titan A.E. cel, cream and brass, rust trim, brown outline, vertex color, no PBR, no subdivision, chunky silhouette, game asset, nose +Z, Nest scrap freelancer hull, Star Fox cousin not a copy
```

Negative: `PBR, photoreal, anime, mint, magenta, Overwatch, 8k, subdivision, smooth CAD, glass reflections`

**Meshy retexture (always, 10 cr):**
```
PS1 Crash cel, Don Bluth Titan A.E. Cream hull, brass trim, rust, wood-and-brass scrap. Flat matte vertex-color, hard edges, no gloss, no PBR, no metallic
```

Same prompt, swap subject: mite chaser / fat brute / brick Bogon barge (silent bg, later).

## Order

1. Rook hull (you see it every frame)
2. Chaser + brute (horde read)
3. Other four mites
4. Guardian (arms then heart)
5. Nest buoy / shard
6. Bogon barge (Gold Paint bg)

True-ending cine is **not** this pass. Ending B only, later.

## Comms blobs

Technique from [Bloub](https://github.com/jeremy-prt/bloub) (radial morph, ease-out, gaze+blink, eyes lean `\\`). Nest skins only — Hatch / Pip / Kite. Not the xAI marks.

## Who does what

AI dumps the clay. You rig and kill the ugly.

1. Meshy / Tripo / Hunyuan / Rodin — prompt above, **low poly**, GLB.
2. Blender: decimate to 500–2k, vertex paint R/G/B, nose +Z, origin center. Kill PBR materials.
3. You rig. Ships are a root + maybe flaps. Hop/roll can stay code on `visual` until clips exist.
4. Drop `godot/assets/meshes/rook.glb`. Shader does the cel.

If it looks like Fortnite, don't rig it. Generate again.

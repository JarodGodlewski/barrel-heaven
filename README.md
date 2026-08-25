# Barrel Heaven

Star Fox all-range × Vampire Survivors horde. Browser prototype — **no game engine, no imported art**.

Ships are flat-shaded geometry. The level is an empty starfield. Weapons auto-fire. You steer and barrel-roll.

## Run

From this folder:

```bash
python -m http.server 8765
```

Then open http://localhost:8765

Modules will not load from `file://`.

## Controls

| Desktop | Mobile |
|---------|--------|
| WASD / arrows steer | Drag to bank and fly |
| Shift boost | — |
| Space (or double A/D) barrel roll | Fast sideways flick to roll |

## Stack

- `index.html` + `css/style.css` + `js/main.js`
- Three.js 0.170 from jsDelivr (ESM)

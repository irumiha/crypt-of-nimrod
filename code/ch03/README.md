# Chapter 3 — Textures, Sprites, and an Atlas

Game state at the end of this chapter: a tiled crypt floor, a chest, a
skull, a spinning coin, and an idling knight, all real pixel art drawn
from one texture atlas at 4× scale.

Build and run: `nimble run`

## Changes from ch02

| File | Status | Notes |
|------|--------|-------|
| `src/resources.nim` | new | `Atlas`: texture + name→Rectangle index parsed from the pack's tile list; `rect`/`frames` lookups |
| `src/sprites.nim` | new | `AnimSprite` (accumulator-pattern animation) + static/animated `draw` procs |
| `src/crypt_of_nimrod.nim` | changed | title scene retired; floor grid rolled once at startup, props, knight |
| `src/embers.nim` | removed | served the title scene |
| `src/tour.nim` | removed | Chapter 2 material |
| `crypt_of_nimrod.nimble` | changed | `tour` task removed |
| `assets/` | unchanged | used for the first time (0x72 Dungeon Tileset II) |

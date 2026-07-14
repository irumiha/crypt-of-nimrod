# Chapter 6 — Tiles, Rooms, and the Camera

Game state at the end of this chapter: the crypt is a real tilemap
(three rooms and corridors, authored as ASCII art in the source),
bigger than the window, with a camera that eases after the knight and
clamps at the map edges. Nothing collides with anything yet — the
knight ghosts through walls until Chapter 7.

Build and run: `nimble run`

## Changes from ch05

| File | Status | Notes |
|------|--------|-------|
| `src/tilemap.nim` | new | `TileKind`/`Tilemap`, ASCII `parseMap`, `tileAt`, `randomFloorPos`, face-vs-top wall rendering via tint; owns the `scale`/`tileSize` consts now |
| `src/camera.nim` | new | `makeCamera`, `follow` (dt-scaled easing, clamped to the map), `adaptToDpi` (HiDPI displays get the same view) |
| `src/crypt_of_nimrod.nim` | changed | the map string; camera wired into the loop; spawns use `randomFloorPos`; Chapter 3's inline floor grid removed |
| `src/ecs.nim` | unchanged | |
| `src/systems.nim` | unchanged | (`bounceSystem` already took bounds as a parameter; it now receives the map's pixel size) |
| `src/sprites.nim` | unchanged | |
| `src/input.nim` | unchanged | |
| `src/resources.nim` | unchanged | |
| `crypt_of_nimrod.nimble` | unchanged | |
| `assets/` | unchanged | |

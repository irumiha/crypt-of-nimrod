# Chapter 10 — Generating the Crypt

Game state at the end of this chapter: every floor is procedurally
generated from a seed (printed at startup; same seed, same crypt): an
Isaac-style grid of screen-sized rooms, each holding enemies, with the
camera locked to the current room and panning on transitions. The
stairs down hide in the deepest room behind gold-sealed doors; the
seal-dissolving flask waits in the second-deepest. Standing on the
stairs descends to a fresh floor with more enemies per room.

Build and run: `nimble run` — tests: `nimble test`

## Changes from ch09

| File | Status | Notes |
|------|--------|-------|
| `src/dungeon.nim` | new | the generator: seeded room walk, BFS depths, doorway carving, seal/unlock, room lookup helpers |
| `tests/tdungeon.nim` | new | determinism, connectivity, distinct special rooms, seal contract, exactly one staircase |
| `src/tilemap.nim` | changed | tile kinds added: `tkSealed` (gold-tinted wall, solid until unsealed) and `tkStairs`; `initTilemap` + `setTile` for generators |
| `src/collision.nim` | changed | sealed tiles are solid |
| `src/ecs.nim` | changed | `PickupKind` (coin/key) component added |
| `src/systems.nim` | changed | `pickupSystem` returns what was picked up, not a count; `aiSystem` takes the dungeon and scopes aggro to the player's room (distance checks don't respect walls, so enemies used to pile up in doorways) |
| `src/camera.nim` | changed | `follow` takes a pan speed (room transitions use a slower one) |
| `src/crypt_of_nimrod.nim` | changed | generated floors replace the hand-drawn map; room-locked camera targeting; key/seal flow; stairs regenerate the next floor |
| `tests/tworld.nim` | changed | pickup test follows `pickupSystem`'s new return type |
| `tests/tcombat.nim` | changed | ai suite runs in a generated crypt; new test: a wall blocks aggro |
| everything else | unchanged | |

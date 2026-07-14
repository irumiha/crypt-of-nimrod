# Chapter 8 — God Mode and Headless Worlds

Game state at the end of this chapter: F1 opens a debug mode with
collider visualization, an entity inspector on the mouse cursor,
noclip, teleport-to-cursor, spawn-at-cursor, and time scaling. The
world also gained headless unit tests (`nimble test`): the real
movement, collision, contact, and lifecycle code running with no
window and no GPU, in CI.

Build and run: `nimble run` — tests: `nimble test`

## Changes from ch07

| File | Status | Notes |
|------|--------|-------|
| `src/debug.nim` | new | the instrument panel: toggles, collider overlay, cursor inspector (`dump` aimed with the mouse), `getScreenToWorld2D` |
| `tests/tworld.nim` | new | headless suites: walls (the ch07 autopilot corner run, now a regression test), contacts/pickups, entity lifecycle |
| `tests/config.nims` | new | points the test build at `../src` |
| `src/tilemap.nim` | changed | testability refactor: `parseMap(ascii)` no longer touches the atlas; looks moved into `TileSkin`/`makeSkin` |
| `src/systems.nim` | changed | `movementSystem` gains a `noclip` parameter (player ignores walls while set) |
| `src/crypt_of_nimrod.nim` | changed | debug wiring (F1/T/E keys, time-scaled dt); `spawnCritter` returns its entity |
| `src/ecs.nim` | unchanged | |
| `src/collision.nim` | unchanged | |
| `src/camera.nim` | unchanged | |
| `src/sprites.nim` | unchanged | |
| `src/input.nim` | unchanged | |
| `src/resources.nim` | unchanged | |
| `crypt_of_nimrod.nimble` | unchanged | (`nimble test` is a built-in task) |
| `assets/` | unchanged | |

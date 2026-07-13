# Chapter 5 — Input and Movement

Game state at the end of this chapter: the knight walks (WASD or
arrows), faces where he's going, and switches between idle and run
animations. The critters inherit the facing and animation polish for
free.

Build and run: `nimble run`

## Changes from ch04

| File | Status | Notes |
|------|--------|-------|
| `src/input.nim` | new | the action map: `Action` enum, bindings table (multiple keys per action), `isDown`, normalized `moveAxis` |
| `src/ecs.nim` | changed | components added: `Actor` (idle/run animation names, + column) and `ckPlayer` (tag, mask-only); `dump` extended |
| `src/systems.nim` | changed | + `playerInputSystem`, + `actorAnimSystem`; `bounceSystem` now also clamps positions into bounds |
| `src/sprites.nim` | changed | `AnimSprite` tracks its animation name (`setAnim` no-ops when unchanged) and gains `flipX` (negative source width flip) |
| `src/crypt_of_nimrod.nim` | changed | knight spawns with Velocity/Actor/Player; critters get `Actor`; schedule grows two systems |
| `src/resources.nim` | unchanged | |
| `crypt_of_nimrod.nimble` | unchanged | |
| `assets/` | unchanged | |

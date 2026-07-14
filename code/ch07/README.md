# Chapter 7 — Collisions

Game state at the end of this chapter: walls are solid. The knight
stops at masonry and slides along it, critters ricochet off the actual
architecture (and can no longer wander into the void), and the knight
collects coins by walking into them. A coin counter joins the HUD.

Build and run: `nimble run`

## Changes from ch06

| File | Status | Notes |
|------|--------|-------|
| `src/collision.nim` | new | `overlapsSolid` (the tile grid as its own spatial index) and axis-separated `moveAndSlide` with flush snapping |
| `src/ecs.nim` | changed | components added: `Collider` (offset/size/layer/hits) and `ckBounce` tag; `Layer` enum; `contacts` frame scratch; `has`, `colliderRect`, `feetCollider` helpers; `dump` extended |
| `src/systems.nim` | changed | `movementSystem` now moves-and-slides collider entities (and reflects `ckBounce`); + `contactSystem` (layer-filtered O(n²) pairs), + `pickupSystem`; old screen-bounds `bounceSystem` removed |
| `src/crypt_of_nimrod.nim` | changed | knight and critters get colliders (feet boxes), coins get pickup colliders, coin counter in the HUD |
| `src/tilemap.nim` | unchanged | |
| `src/camera.nim` | unchanged | |
| `src/sprites.nim` | unchanged | |
| `src/input.nim` | unchanged | |
| `src/resources.nim` | unchanged | |
| `crypt_of_nimrod.nimble` | unchanged | |
| `assets/` | unchanged | |

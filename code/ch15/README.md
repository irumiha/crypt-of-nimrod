# Chapter 15 — Shaders: The GPU Joins the Party

Game state at the end of this chapter: two fragment shaders. Hovering
a pickup with the mouse outlines it in gold and names it (a hover
system feeds the draw system through frame scratch, like every other
cross-system handoff), and C toggles a CRT filter — curvature,
scanlines, vignette — applied to the whole frame during the canvas
blit. Shaders ship in two dialects: GLSL 330 for desktop, GLSL 100
twins for the web build, chosen at compile time.

Build and run: `nimble run` — tests: `nimble test`

## Changes from ch14

| File | Status | Notes |
|------|--------|-------|
| `shaders/*.fs` | new | `outline` and `crt` fragment shaders, each in a 330 and a 100 dialect (next to `src/`: they're code, and `assets/` is a synced mirror of the art pack) |
| `src/shaders.nim` | new | `Fx`: loads both shaders, sets the never-changing uniforms once, feeds the per-draw `region` uniform |
| `tests/tshaders.nim` | new | hover pick math; every 330 shader has a 100 twin declaring identical uniforms |
| `src/ecs.nim` | changed | + `hovered` frame scratch (slot under the cursor, or −1) |
| `src/systems.nim` | changed | + `hoverSystem`; `drawSystem` draws the hovered pickup through the outline shader |
| `src/sprites.nim` | changed | + `srcRect` (the current frame's atlas cell, for the outline's region clamp) |
| `src/loot.nim` | changed | + `label` (what the hover UI calls each pickup) |
| `src/input.nim` | changed | + `aCrt` action (C) |
| `src/crypt_of_nimrod.nim` | changed | loads `Fx`, runs the hover system, draws the hover label, wraps the blit in the CRT shader when toggled |
| everything else | unchanged | |

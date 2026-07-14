# Chapter 12 — HUD and UI

Game state at the end of this chapter: the game presents itself.
Hearts instead of an hp string, icon stats for coins/power/floor/seal,
a minimap built straight from the floor graph (gold = sealed stairs,
outline = you), and floating damage numbers that jump out of whoever
got hurt, drift up, and fade. Damage flows to the UI through a new
`damageEvents` frame scratch that Chapter 14's game feel will reuse.

Build and run: `nimble run` — tests: `nimble test`

## Changes from ch11

| File | Status | Notes |
|------|--------|-------|
| `src/hud.nim` | new | hearts row, `drawIconStat`, minimap from the dungeon's room graph, world-space `drawFloatingTexts` |
| `src/ecs.nim` | changed | `ckFloatText` component (+ column); `DamageEvent` + `damageEvents` frame scratch |
| `src/systems.nim` | changed | `damageSystem` publishes damage events |
| `src/crypt_of_nimrod.nim` | changed | text HUD replaced by `drawHud`; damage numbers spawned from events (velocity + lifetime reuse the existing systems) |
| `tests/tcombat.nim` | changed | damage events tested (one per hit, none during i-frames) |
| everything else | unchanged | |

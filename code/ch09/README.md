# Chapter 9 — Enemies and Melee Combat

Game state at the end of this chapter: the critters are enemies. They
wander until the knight gets close, then chase; touching him costs a
hit point, stuns briefly, and knocks him back (with i-frames so it
stays fair). The knight swings a sword (Space or J) that damages and
knocks back enemies; the dead leave skulls. HP, coins, and kills on
the HUD. New combat behavior ships with new headless tests.

Build and run: `nimble run` — tests: `nimble test`

## Changes from ch08

| File | Status | Notes |
|------|--------|-------|
| `tests/tcombat.nim` | new | damage/i-frames/knockback/death suites, plus enemy AI chase and hysteresis |
| `src/ecs.nim` | changed | components added: `Health` (hp + invuln + stun timers), `Ai` (state enum, chase speed, aggro), `ContactDamage` (amount + knockback); `lyPlayerAttack` layer; `dump` extended |
| `src/systems.nim` | changed | + `aiSystem` (wander/chase with slack), + `healthSystem`, + `damageSystem` (contacts → hp/i-frames/stun/knockback), + `deathSystem` (returns where things fell; GPU-free); input waits while stunned |
| `src/input.nim` | changed | `aAttack` action (Space/J) and `wasPressed` |
| `src/sprites.nim` | changed | `initStaticSprite` for one-frame sprites (sword, skull) |
| `src/camera.nim` | changed | `adaptToDpi`: bakes display scale into the camera (also backported to ch06–ch08, where the camera lives) |
| `src/crypt_of_nimrod.nim` | changed | enemy archetype table, `spawnEnemy` bundles, `swingSword`, death decals, merciful respawn, HUD hp/kills |
| `src/debug.nim` | changed | panel moved below the taller HUD |
| everything else | unchanged | |

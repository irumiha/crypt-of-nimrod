# Chapter 16 — The Boss and the Run

Game state at the end of this chapter: a run that can be won. Floor 3
is the last one — no stairs, and the deepest room is a throne room
where the Warden (a very big demon) keeps the crown. The seals slam
shut behind you, the fight gets a health bar, the Warden enrages at
half health and calls imps, and its death drops the Chapter 1
programmer-art crown as a real pickup. Touching it ends the run in a
fifth game phase, `gpVictory`, which the compiler demanded arms for
across the whole program. Enemy stats moved to a bestiary module and
now scale per floor.

Build and run: `nimble run` — tests: `nimble test`

## Changes from ch15

| File | Status | Notes |
|------|--------|-------|
| `src/bestiary.nim` | new | enemy stats table (moved out of main), `scaled` per-floor difficulty, the `warden`, the `imp` |
| `tests/tboss.nim` | new | scaling curve, phase flip, minion cadence, final-floor shape, relock round trip, insideRoom |
| `src/ecs.nim` | changed | + `ckBoss`, `Boss` (phase, minion timer), `pkCrown`; dump knows the boss |
| `src/systems.nim` | changed | + `bossSystem` (enrage at half hp, minion calls on a cadence), `findBoss` |
| `src/dungeon.nim` | changed | `generate` takes `final` (no stairs on the last floor); `unlock` remembers the doors so `relock` can slam them; `insideRoom` |
| `src/hud.nim` | changed | + `drawBossBar` |
| `src/audio.nim` | changed | + `sfxRoar` (enrage), `sfxVictory` (C-E-G jingle) |
| `src/loot.nim` | changed | crown label; `applyPickup` treats the crown like coins/keys (the run's business) |
| `src/crypt_of_nimrod.nim` | changed | `gpVictory` phase, boss wiring (lock-in, roar, minion cap by throne-room census, death ceremony), crown drawn with the Chapter 1 primitives, victory screen, `counted` plurals |
| everything else | unchanged | |

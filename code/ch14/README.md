# Chapter 14 — Game Feel

Game state at the end of this chapter: hits land. Kills burst into
debris (a structure-of-arrays particle system, deliberately outside
the ECS), the screen shakes on impact with a trauma-squared response,
whatever got hurt flashes red, the knight blinks through his i-frames,
and hitstop freezes the simulation for three frames when a blow
connects. All of it hangs off Chapter 12's damage events; combat code
is untouched.

Build and run: `nimble run` — tests: `nimble test`

## Changes from ch13

| File | Status | Notes |
|------|--------|-------|
| `src/particles.nim` | new | parallel arrays (bodies/life/colors in lockstep), radial `emitBurst`, hot-loop update + swap-pop compaction across all arrays |
| `tests/tfeel.nim` | new | burst counts, lockstep compaction, drag, trauma clamp/decay, displacement bounds |
| `src/camera.nim` | changed | + `Shake` (trauma-based, squared response, 6 px max) |
| `src/sprites.nim` | changed | animated `draw` takes a tint |
| `src/systems.nim` | changed | `drawSystem`: red hurt-flash while stunned, player blinks at 10 Hz during i-frames |
| `src/crypt_of_nimrod.nim` | changed | hitstop (sim `dt` zeroed briefly on hits), shake wiring, bursts on hits/deaths, shaken camera copy at draw time |
| everything else | unchanged | |

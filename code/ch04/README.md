# Chapter 4 — An ECS in an Afternoon

Game state at the end of this chapter: ten critters bounce around the
crypt, coins spawn and expire (watch the entity counter plateau as the
free list recycles slots), and the knight stands still because no
system has any business with him.

Build and run: `nimble run`

## Changes from ch03

| File | Status | Notes |
|------|--------|-------|
| `src/ecs.nim` | new | the whole ECS: generational `Entity` handles, component columns in a `World`, bitset-mask queries, `dump` |
| `src/systems.nim` | new | movement, bounce, animation, lifetime, draw — each with a `Reads:`/`Writes:` declaration |
| `src/sprites.nim` | changed | scale moved into `AnimSprite`; `width`/`height` accessors added |
| `src/crypt_of_nimrod.nim` | changed | spawn procs (critters, coins), knight becomes an entity, frame loop becomes a list of system calls |
| `src/resources.nim` | unchanged | |
| `crypt_of_nimrod.nimble` | unchanged | |
| `assets/` | unchanged | |

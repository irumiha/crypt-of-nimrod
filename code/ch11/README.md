# Chapter 11 — Loot, Items, and Pickups

Game state at the end of this chapter: the coin faucet is gone; loot
falls from dead enemies via a weighted drop table. Coins count, hearts
heal (never past max), the blue flask permanently raises max hp, and
the green flask sharpens the sword. Drops expire after a while, and
balancing the whole economy means editing one table.

Build and run: `nimble run` — tests: `nimble test`

## Changes from ch10

| File | Status | Notes |
|------|--------|-------|
| `src/loot.nim` | new | `DropTable`/`DropEntry`, cumulative-weight `roll` (explicit `var Rand`, returns `Option`), `applyPickup` effects, the `enemyDrops` table |
| `tests/tloot.nim` | new | drop distribution (shape, not decimals), same-dice determinism, heal clamp, flask effects |
| `src/ecs.nim` | changed | `PickupKind` grew `pkHeart`, `pkMaxHp`, `pkPower` |
| `src/crypt_of_nimrod.nim` | changed | `spawnCoin` faucet removed; `spawnLoot` per kind; death rolls the table; `swingSword` takes a damage stat; `power` on the HUD |
| everything else | unchanged | |

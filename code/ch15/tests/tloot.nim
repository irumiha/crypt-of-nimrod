## Headless tests for the drop table and pickup effects. The table
## takes explicit dice, so its statistics are reproducible enough to
## assert against.

import std/[options, random]
import unittest
import raylib
import ecs, loot

suite "drop table":
  test "weights are honored over many rolls, nothing included":
    var rng = initRand(1234)
    var counts: array[PickupKind, int]
    var nothing = 0
    for _ in 1..10_000:
      let r = enemyDrops.roll(rng)
      if r.isSome:
        inc counts[r.get]
      else:
        inc nothing
    # Total weight is 100, so weights read as percentages. Allow
    # generous slack; this asserts the shape, not the decimals.
    check nothing in 4_500..5_700          # weight 51
    check counts[pkCoin] in 2_500..3_500   # weight 30
    check counts[pkHeart] in 800..1_600    # weight 12
    check counts[pkPower] in 200..700      # weight 4
    check counts[pkMaxHp] in 100..600      # weight 3
    check counts[pkKey] == 0               # keys never drop

  test "the same dice roll the same drops":
    var a = initRand(7)
    var b = initRand(7)
    for _ in 1..100:
      check enemyDrops.roll(a) == enemyDrops.roll(b)

suite "pickup effects":
  setup:
    var world = World()
    let player = world.spawn({ckPosition, ckPlayer, ckHealth})
    world.healths[player.idx] = Health(hp: 3, maxHp: 6)
    var power: int32 = 1

  test "a heart heals one, and never past max":
    world.applyPickup(player, power, pkHeart)
    check world.healths[player.idx].hp == 4
    world.healths[player.idx].hp = 6
    world.applyPickup(player, power, pkHeart)
    check world.healths[player.idx].hp == 6   # already full

  test "the blue flask raises the ceiling and fills the gap it made":
    world.applyPickup(player, power, pkMaxHp)
    check world.healths[player.idx].maxHp == 7
    check world.healths[player.idx].hp == 4

  test "the green flask sharpens the sword":
    world.applyPickup(player, power, pkPower)
    check power == 2

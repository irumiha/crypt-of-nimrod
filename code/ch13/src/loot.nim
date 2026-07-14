## Drop tables and pickup effects: what falls out of a dead enemy,
## and what touching it does to you.
##
## The table takes its dice (a var Rand) from the caller, the same
## lesson as the dungeon generator: explicit randomness is testable
## randomness. Rolling is plain cumulative-weight selection; balancing
## the game's economy is editing the table at the bottom.

import std/[options, random]
import ecs

type
  DropEntry* = object
    kind*: PickupKind
    weight*: int32

  DropTable* = object
    ## Weighted outcomes plus a weight for dropping nothing at all.
    ## Weights are relative; they don't need to sum to anything neat.
    entries*: seq[DropEntry]
    nothing*: int32

proc roll*(t: DropTable, rng: var Rand): Option[PickupKind] =
  ## One roll: walk the cumulative weights, land somewhere.
  var total = t.nothing
  for e in t.entries:
    total += e.weight
  var pick = rng.rand(int32(1)..total)
  for e in t.entries:
    if pick <= e.weight:
      return some(e.kind)
    pick -= e.weight
  none(PickupKind)   # landed in the "nothing" band

proc applyPickup*(w: var World, player: Entity, power: var int32,
                  kind: PickupKind) =
  ## The effect of touching a pickup, for the kinds that change the
  ## player. Coins and keys mean something to the caller, not to the
  ## knight's body, so they are handled where they're counted.
  case kind
  of pkHeart:
    let h = w.healths[player.idx].maxHp
    w.healths[player.idx].hp = min(w.healths[player.idx].hp + 1, h)
  of pkMaxHp:
    inc w.healths[player.idx].maxHp
    inc w.healths[player.idx].hp
  of pkPower:
    inc power
  of pkCoin, pkKey:
    discard

const enemyDrops* = DropTable(
  entries: @[
    DropEntry(kind: pkCoin,  weight: 30),
    DropEntry(kind: pkHeart, weight: 12),
    DropEntry(kind: pkPower, weight: 4),
    DropEntry(kind: pkMaxHp, weight: 3)],
  nothing: 51)

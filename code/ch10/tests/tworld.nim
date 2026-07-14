## Headless tests for the game world: the real systems, the real
## collision code, no window and no GPU. Run with `nimble test`.
##
## What gets tested here is invariants (positions, liveness, counts),
## not feel. Feel stays in the playtester's hands, where it belongs.

import std/unittest
import raylib
import ecs, systems, tilemap

const tinyMap = """
########
#......#
#......#
########"""
  # 8x4 tiles: floor spans x 64..447, y 64..191 in world pixels.

proc spawnBox(w: var World, x, y: float32,
              vx: float32 = 0, vy: float32 = 0,
              extra: set[CompKind] = {}): Entity =
  ## A 32x32 test entity; no sprite, because nothing here draws.
  result = w.spawn({ckPosition, ckVelocity, ckCollider} + extra)
  w.positions[result.idx] = Vector2(x: x, y: y)
  w.velocities[result.idx] = Vector2(x: vx, y: vy)
  w.colliders[result.idx] = Collider(size: Vector2(x: 32, y: 32))

suite "walls":
  # The Chapter 7 autopilot, promoted to a regression test.
  setup:
    var world = World()
    let map = parseMap(tinyMap)

  test "driving right stops flush against the wall":
    let e = world.spawnBox(x = 96, y = 96, vx = 400)
    for _ in 1..120:
      world.movementSystem(map, 1/60)
    check world.positions[e.idx].x == float32(7*tileSize) - 32
    check world.positions[e.idx].y == 96

  test "diagonal movement slides along the wall, then corners":
    let e = world.spawnBox(x = 96, y = 96, vx = 400, vy = 100)
    for _ in 1..120:
      world.movementSystem(map, 1/60)
    # Pinned in the bottom-right inner corner, flush on both axes.
    check world.positions[e.idx].x == float32(7*tileSize) - 32
    check world.positions[e.idx].y == float32(3*tileSize) - 32

  test "the bounce tag reflects velocity off a wall":
    let e = world.spawnBox(x = 400, y = 96, vx = 400, extra = {ckBounce})
    for _ in 1..10:
      world.movementSystem(map, 1/60)
    check world.velocities[e.idx].x == -400
    check world.positions[e.idx].x < float32(7*tileSize) - 32

suite "contacts and pickups":
  test "the player picks up an overlapping coin, and only touches once":
    var world = World()
    let player = world.spawnBox(x = 100, y = 100)
    world.colliders[player.idx].layer = lyPlayer
    world.colliders[player.idx].hits = {lyPickup}
    let coin = world.spawnBox(x = 110, y = 110, extra = {ckPickup})
    world.colliders[coin.idx].layer = lyPickup
    world.pickupKinds[coin.idx] = pkCoin
    let bystander = world.spawnBox(x = 112, y = 112)
    world.colliders[bystander.idx].layer = lyEnemy

    world.contactSystem()
    check world.pickupSystem() == @[pkCoin]
    check not world.alive(coin)
    check world.alive(bystander)   # enemies are not currency

suite "entity lifecycle":
  test "a stale handle reads dead after its slot is reused":
    var world = World()
    let first = world.spawn({ckPosition})
    world.despawn(first)
    let second = world.spawn({ckPosition})
    check second.idx == first.idx   # the slot was recycled...
    check not world.alive(first)    # ...and the old handle knows it
    check world.alive(second)
    check world.entityCount == 1

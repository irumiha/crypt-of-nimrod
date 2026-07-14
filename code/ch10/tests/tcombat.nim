## Headless combat tests: damage, i-frames, knockback, death, and the
## enemy state machine, all through the real systems.

import std/unittest
import raylib, raymath
import ecs, systems

proc fighter(w: var World, x, y: float32, hp: int32, layer: Layer,
             hits: set[Layer] = {}, dmg: int32 = 0): Entity =
  ## A 32x32 combatant with health, and contact damage when dmg > 0.
  var comps = {ckPosition, ckVelocity, ckCollider, ckHealth}
  if dmg > 0:
    comps.incl(ckContactDamage)
  result = w.spawn(comps)
  w.positions[result.idx] = Vector2(x: x, y: y)
  w.colliders[result.idx] = Collider(
    size: Vector2(x: 32, y: 32), layer: layer, hits: hits)
  w.healths[result.idx] = Health(hp: hp, maxHp: hp, invulnTime: 0.5)
  if dmg > 0:
    w.contactDamages[result.idx] = ContactDamage(amount: dmg,
                                                 knockback: 600)

suite "damage":
  setup:
    var world = World()
    let sword = world.fighter(x = 100, y = 100, hp = 1,
                              layer = lyPlayerAttack,
                              hits = {lyEnemy}, dmg = 1)
    let victim = world.fighter(x = 110, y = 100, hp = 3, layer = lyEnemy)

  test "contact damage lands once per invulnerability window":
    world.contactSystem()
    world.damageSystem()
    check world.healths[victim.idx].hp == 2
    world.contactSystem()
    world.damageSystem()           # still inside the i-frame window
    check world.healths[victim.idx].hp == 2
    world.healthSystem(0.6)        # window expires
    world.contactSystem()
    world.damageSystem()
    check world.healths[victim.idx].hp == 1

  test "knockback shoves the victim away from the hit":
    world.contactSystem()
    world.damageSystem()
    check world.velocities[victim.idx].x > 0   # attacker is to the left
    check world.healths[victim.idx].stun > 0

  test "deathSystem buries the dead and reports where":
    world.healths[victim.idx].hp = 1
    world.contactSystem()
    world.damageSystem()
    let fallen = world.deathSystem()
    check fallen.len == 1
    check fallen[0].x == 110
    check not world.alive(victim)

suite "enemy ai":
  setup:
    var world = World()
    let player = world.spawn({ckPosition, ckPlayer})
    world.positions[player.idx] = Vector2(x: 50, y: 0)
    let enemy = world.spawn({ckPosition, ckVelocity, ckAi})
    world.ais[enemy.idx] = Ai(chaseSpeed: 100, aggro: 100)

  test "wander flips to chase inside aggro range, and steers":
    world.aiSystem(player)
    check world.ais[enemy.idx].state == asChase
    check world.velocities[enemy.idx].x > 0    # toward the player

  test "chase gives up beyond the slack boundary, not at it":
    world.aiSystem(player)                      # now chasing
    world.positions[player.idx].x = 130         # past aggro, inside slack
    world.aiSystem(player)
    check world.ais[enemy.idx].state == asChase # hysteresis holds it
    world.positions[player.idx].x = 500         # decisively gone
    world.aiSystem(player)
    check world.ais[enemy.idx].state == asWander

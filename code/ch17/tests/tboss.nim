## Chapter 16: the boss and the run, tested headless. The phase flip,
## the minion cadence, the difficulty curve, and the final floor's
## shape are all arithmetic; the fight itself is the playtester's.

import std/unittest
import raylib
import bestiary, dungeon, ecs, loot, systems, tilemap

proc makeWarden(w: var World): Entity =
  result = w.spawn({ckBoss, ckHealth, ckAi, ckPosition})
  w.healths[result.idx] = Health(hp: 20, maxHp: 20)
  w.ais[result.idx] = Ai(chaseSpeed: 55, aggro: 420)

suite "difficulty scaling":
  test "floor one is the table, verbatim":
    for s in enemyKinds:
      check s.scaled(1) == s

  test "floor three: +1 hp, 16% faster":
    let g = enemyKinds[0].scaled(3)
    check g.hp == enemyKinds[0].hp + 1
    check abs(g.speed - enemyKinds[0].speed*1.16) < 0.001

  test "deeper floors never get easier":
    for floor in 1..9:
      let a = imp.scaled(floor)
      let b = imp.scaled(floor + 1)
      check b.hp >= a.hp
      check b.speed >= a.speed

suite "the boss's brain":
  test "healthy boss stalks and calls nobody":
    var w: World
    let b = w.makeWarden()
    for _ in 1..10:
      check w.bossSystem(0.5).len == 0
    check w.bosses[b.idx].phase == bpStalk

  test "half health enrages, once, and speeds the chase":
    var w: World
    let b = w.makeWarden()
    w.healths[b.idx].hp = 10
    discard w.bossSystem(0.016)
    check w.bosses[b.idx].phase == bpEnrage
    check abs(w.ais[b.idx].chaseSpeed - 55*1.6) < 0.001
    discard w.bossSystem(0.016)
    check abs(w.ais[b.idx].chaseSpeed - 55*1.6) < 0.001   # no double dip

  test "an enraged boss calls minions on a 3.5 s cadence":
    var w: World
    let b = w.makeWarden()
    w.healths[b.idx].hp = 1
    check w.bossSystem(0.016).len == 0   # the flip frame only flips
    check w.bossSystem(0.016).len == 1   # the first call comes at once
    check w.bossSystem(1.0).len == 0
    check w.bossSystem(3.0).len == 1     # the 3.5 s cadence
    check w.bossSystem(0.1).len == 0

  test "findBoss sees the boss, and only while it lives":
    var w: World
    check w.findBoss() == -1
    let b = w.makeWarden()
    check w.findBoss() == b.idx
    w.despawn(b)
    check w.findBoss() == -1

suite "the final floor":
  test "no stairs anywhere; the throne room is sealed":
    let d = generate(20260714, 3, final = true)
    for y in 0'i32 ..< int32(roomRows*roomH):
      for x in 0'i32 ..< int32(roomCols*roomW):
        check d.map.tileAt(x, y) != tkStairs
    check d.isLocked

  test "seals dissolve, then slam shut again":
    var d = generate(99, 3, final = true)
    check d.isLocked
    d.unlock()
    check not d.isLocked
    d.relock()
    check d.isLocked
    d.unlock()                 # the Warden falls; out you go
    check not d.isLocked

  test "insideRoom knows the interior from the doorway":
    let d = generate(7, 3, final = true)
    check d.insideRoom(d.stairsRoom, d.roomCenter(d.stairsRoom))
    # A point on the room's border wall column is not "well inside".
    let r = d.rooms[d.stairsRoom]
    let doorway = Vector2(
      x: float32(r.gx*roomW*tileSize),
      y: float32(r.gy*roomH*tileSize) + roomH*tileSize/2)
    check not d.insideRoom(d.stairsRoom, doorway)

suite "the crown":
  test "it has a name for the hover UI":
    check label(pkCrown) == "the crown of Nimrod"

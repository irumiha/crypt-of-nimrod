## Chapter 12: the game learns to present itself. Hearts instead of
## an hp string, icon stats, a minimap built from the floor graph,
## and floating damage numbers in world space, driven by the damage
## events the combat system now publishes.

import std/[options, random]
import raylib, raymath
import camera, debug, dungeon, ecs, hud, input, loot, resources,
       sprites, systems, tilemap

const
  screenWidth = 800
  screenHeight = 450
  playerSpeed = 170
  attackCooldownTime = 0.35
  backgroundColor = Color(r: 24, g: 20, b: 37, a: 255)
  atlasDir = "assets/0x72_DungeonTilesetII_v1.7/"

type
  EnemyStats = object
    name: string
    hp: int32
    speed: float32
    aggro: float32

const enemyKinds = [
  EnemyStats(name: "goblin", hp: 2, speed: 85, aggro: 150),
  EnemyStats(name: "skelet", hp: 2, speed: 70, aggro: 170),
  EnemyStats(name: "imp",    hp: 1, speed: 95, aggro: 140),
  EnemyStats(name: "chort",  hp: 3, speed: 80, aggro: 160),
  EnemyStats(name: "ogre",   hp: 5, speed: 45, aggro: 190)]

proc spawnEnemy(w: var World, atlas: Atlas,
                pos: Vector2): Entity {.discardable.} =
  ## One archetype from the table, assembled as a component bundle.
  let stats = enemyKinds[rand(enemyKinds.high)]
  let e = w.spawn({ckPosition, ckVelocity, ckSprite, ckActor,
                   ckCollider, ckBounce, ckHealth, ckAi,
                   ckContactDamage})
  w.sprites[e.idx] = initAnimSprite(atlas, stats.name & "_idle_anim", scale)
  w.actors[e.idx] = Actor(idleAnim: stats.name & "_idle_anim",
                          runAnim: stats.name & "_run_anim")
  w.colliders[e.idx] = feetCollider(w.sprites[e.idx], lyEnemy,
                                    hits = {lyPlayer})
  w.healths[e.idx] = Health(hp: stats.hp, maxHp: stats.hp,
                            invulnTime: 0.3)
  w.ais[e.idx] = Ai(chaseSpeed: stats.speed, aggro: stats.aggro)
  w.contactDamages[e.idx] = ContactDamage(amount: 1, knockback: 250)
  w.positions[e.idx] = pos
  w.velocities[e.idx] = Vector2(
    x: float32(rand(-60.0..60.0)),
    y: float32(rand(-60.0..60.0)))
  e

proc spawnLoot(w: var World, atlas: Atlas, pos: Vector2,
               kind: PickupKind) =
  ## One dropped item where an enemy fell. Drops expire after a while;
  ## the crypt keeps a tidy floor.
  let e = w.spawn({ckPosition, ckSprite, ckLifetime, ckCollider,
                   ckPickup})
  w.sprites[e.idx] = case kind
    of pkCoin: initAnimSprite(atlas, "coin_anim", scale)
    of pkHeart: initStaticSprite(atlas, "ui_heart_full", scale)
    of pkMaxHp: initStaticSprite(atlas, "flask_big_blue", scale)
    of pkPower: initStaticSprite(atlas, "flask_big_green", scale)
    of pkKey: initStaticSprite(atlas, "flask_big_yellow", scale)
  w.colliders[e.idx] = Collider(
    size: Vector2(x: w.sprites[e.idx].width, y: w.sprites[e.idx].height),
    layer: lyPickup)
  w.pickupKinds[e.idx] = kind
  w.positions[e.idx] = pos
  w.lifetimes[e.idx] = 12

proc spawnKey(w: var World, atlas: Atlas, pos: Vector2) =
  ## The seal-dissolving flask. Persistent: no lifetime, it waits.
  let e = w.spawn({ckPosition, ckSprite, ckCollider, ckPickup})
  w.sprites[e.idx] = initStaticSprite(atlas, "flask_big_yellow", scale)
  w.colliders[e.idx] = Collider(
    size: Vector2(x: w.sprites[e.idx].width, y: w.sprites[e.idx].height),
    layer: lyPickup)
  w.pickupKinds[e.idx] = pkKey
  w.positions[e.idx] = pos

proc swingSword(w: var World, atlas: Atlas, player: Entity,
                damage: int32) =
  ## The sword: an entity with a sprite, a hitbox slightly bigger than
  ## the blade, one point of damage, and 0.15 seconds to live.
  let facingLeft = w.sprites[player.idx].flipX
  let e = w.spawn({ckPosition, ckSprite, ckCollider, ckLifetime,
                   ckContactDamage})
  w.sprites[e.idx] = initStaticSprite(atlas, "weapon_knight_sword", scale)
  w.sprites[e.idx].flipX = facingLeft
  let px = w.positions[player.idx]
  w.positions[e.idx] = Vector2(
    x: if facingLeft: px.x - w.sprites[e.idx].width
       else: px.x + w.sprites[player.idx].width,
    y: px.y + 6)
  w.colliders[e.idx] = Collider(
    offset: Vector2(x: -6, y: -6),
    size: Vector2(x: w.sprites[e.idx].width + 12,
                  y: w.sprites[e.idx].height + 12),
    layer: lyPlayerAttack, hits: {lyEnemy})
  w.contactDamages[e.idx] = ContactDamage(amount: damage,
                                          knockback: 300)
  w.lifetimes[e.idx] = 0.15

proc spawnDamageNumber(w: var World, ev: DamageEvent) =
  ## A little number that jumps out of whoever got hurt, drifts up,
  ## and fades. Pure presentation, so it lives outside the systems.
  let e = w.spawn({ckPosition, ckVelocity, ckLifetime, ckFloatText})
  w.positions[e.idx] = ev.pos
  w.velocities[e.idx] = Vector2(x: 0, y: -30)
  w.lifetimes[e.idx] = 0.7
  w.floatTexts[e.idx] = $ev.amount

proc populateFloor(w: var World, d: Dungeon, atlas: Atlas,
                   floorNum: int, carryHp: int32): Entity =
  ## A fresh World for a fresh floor: the knight (keeping his hp from
  ## the stairs), enemies in every room but his, and the key.
  result = w.spawn({ckPosition, ckVelocity, ckSprite, ckActor,
                    ckPlayer, ckCollider, ckHealth})
  w.sprites[result.idx] = initAnimSprite(atlas, "knight_m_idle_anim", scale)
  w.actors[result.idx] = Actor(idleAnim: "knight_m_idle_anim",
                               runAnim: "knight_m_run_anim")
  w.colliders[result.idx] = feetCollider(
    w.sprites[result.idx], lyPlayer, hits = {lyPickup})
  w.healths[result.idx] = Health(hp: carryHp, maxHp: 6, invulnTime: 0.8)
  w.positions[result.idx] = d.roomCenter(d.startRoom) -
                            Vector2(x: 16, y: 28)

  # Deeper floors pack more enemies into every room.
  let perRoom = min(2 + floorNum, 6)
  for i in 0 ..< d.rooms.len:
    if i != d.startRoom:
      for _ in 1..perRoom:
        w.spawnEnemy(atlas, d.randomPosIn(i))
  w.spawnKey(atlas, d.randomPosIn(d.keyRoom))

proc main =
  randomize()
  setConfigFlags(flags(WindowHighdpi))
  initWindow(screenWidth, screenHeight, "Crypt of Nimrod")
  defer: closeWindow()
  setTargetFPS(60)

  let atlas = loadAtlas(
    atlasDir & "0x72_DungeonTilesetII_v1.7.png",
    atlasDir & "tile_list_v1.7")
  let skin = makeSkin(atlas)

  # One run seed makes every floor of this run reproducible; print it
  # so a bug report can say "seed 12345, floor 3".
  let runSeed = int64(rand(1_000_000))
  echo "run seed: ", runSeed

  var floorNum = 1
  var crypt = generate(runSeed, floorNum)
  # Loot gets its own dice too, so drops never disturb the map seed.
  var dropRng = initRand(runSeed xor 0x10071)
  var world = World()
  var knight = world.populateFloor(crypt, atlas, floorNum, carryHp = 6)

  var cam = makeCamera(Vector2(x: screenWidth, y: screenHeight))
  cam.target = crypt.roomCenter(crypt.startRoom)

  var coinsCollected = 0
  var kills = 0
  var swordPower: int32 = 1     # sword damage; the green flask raises it
  var attackCooldown: float32 = 0
  var dbg = initDebug()

  while not windowShouldClose():
    # --- Update ---
    dbg.update()
    let dt = getFrameTime()*dbg.timeScale
    if dbg.enabled:
      if isKeyPressed(T):
        world.positions[knight.idx] = mouseWorld(cam)
      if isKeyPressed(E):
        world.spawnEnemy(atlas, mouseWorld(cam))
    attackCooldown -= dt
    if wasPressed(aAttack) and attackCooldown <= 0:
      attackCooldown = attackCooldownTime
      world.swingSword(atlas, knight, swordPower)
    world.playerInputSystem(playerSpeed)
    world.aiSystem(knight)
    world.healthSystem(dt)
    world.movementSystem(crypt.map, dt, dbg.noclip)
    world.contactSystem()
    world.damageSystem()
    for ev in world.damageEvents:
      world.spawnDamageNumber(ev)
    for spot in world.deathSystem():
      inc kills
      let d = world.spawn({ckPosition, ckSprite, ckLifetime})
      world.sprites[d.idx] = initStaticSprite(atlas, "skull", scale)
      world.positions[d.idx] = spot
      world.lifetimes[d.idx] = 4
      # The dead pay their respects: one roll on the drop table.
      let drop = enemyDrops.roll(dropRng)
      if drop.isSome:
        world.spawnLoot(atlas, spot + Vector2(x: 8, y: 8), drop.get)
    if world.healths[knight.idx].hp <= 0:
      # Death proper arrives with Chapter 13's state machine; for now
      # the crypt is merciful and sends him back to this floor's start.
      world.healths[knight.idx].hp = world.healths[knight.idx].maxHp
      world.healths[knight.idx].invuln = 1.5
      world.positions[knight.idx] = crypt.roomCenter(crypt.startRoom) -
                                    Vector2(x: 16, y: 28)
    for kind in world.pickupSystem():
      case kind
      of pkCoin: inc coinsCollected
      of pkKey: crypt.unlock()
      else: world.applyPickup(knight, swordPower, kind)
    world.actorAnimSystem(atlas)
    world.animationSystem(dt)
    world.lifetimeSystem(dt)

    # Standing on the stairs takes them.
    let feet = world.colliderRect(knight.idx)
    let feetTile = Vector2(x: feet.x + feet.width/2,
                           y: feet.y + feet.height/2)
    if crypt.map.tileAt(int32(feetTile.x) div tileSize,
                        int32(feetTile.y) div tileSize) == tkStairs:
      inc floorNum
      let hp = world.healths[knight.idx].hp
      crypt = generate(runSeed + int64(floorNum)*7919, floorNum)
      world = World()
      knight = world.populateFloor(crypt, atlas, floorNum, carryHp = hp)
      cam.target = crypt.roomCenter(crypt.startRoom)

    # The camera locks to whichever room holds the knight and pans on
    # transitions (Chapter 6's easing, aimed at room centers).
    cam.adaptToDpi(Vector2(x: screenWidth, y: screenHeight))
    let knightCenter = world.positions[knight.idx] + Vector2(
      x: world.sprites[knight.idx].width/2,
      y: world.sprites[knight.idx].height/2)
    let room = crypt.roomAt(knightCenter)
    let camTarget = if room >= 0: crypt.roomCenter(room)
                    else: knightCenter   # mid-doorway: follow him
    cam.follow(camTarget, crypt.map.pixelSize, dt, speed = 6)

    # --- Draw ---
    beginDrawing()
    clearBackground(backgroundColor)
    beginMode2D(cam)
    crypt.map.draw(atlas, skin)
    world.drawSystem(atlas)
    drawFloatingTexts(world)       # world-space UI rides the camera
    dbg.drawWorld(world)
    endMode2D()
    dbg.drawPanel(world, cam)
    drawHud(atlas, crypt, room, world.healths[knight.idx],
            coinsCollected, swordPower, floorNum, screenWidth)
    drawFPS(10, 10)
    endDrawing()

main()

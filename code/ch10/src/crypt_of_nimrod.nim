## Chapter 10: the crypt generates itself. Every floor is an
## Isaac-style grid of screen-sized rooms built from a seed, the
## camera locks to the current room and pans on transitions, the
## stairs down hide behind gold-sealed doors, and a flask of solvent
## (this pack has no key sprite; improvise) dissolves them. Stairs
## descend to a fresh, slightly meaner floor.

import std/random
import raylib, raymath
import camera, debug, dungeon, ecs, input, resources, sprites, systems,
       tilemap

const
  screenWidth = 1600
  screenHeight = 900
  playerSpeed = 340
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
  EnemyStats(name: "goblin", hp: 2, speed: 170, aggro: 300),
  EnemyStats(name: "skelet", hp: 2, speed: 140, aggro: 340),
  EnemyStats(name: "imp",    hp: 1, speed: 190, aggro: 280),
  EnemyStats(name: "chort",  hp: 3, speed: 160, aggro: 320),
  EnemyStats(name: "ogre",   hp: 5, speed: 90,  aggro: 380)]

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
  w.contactDamages[e.idx] = ContactDamage(amount: 1, knockback: 500)
  w.positions[e.idx] = pos
  w.velocities[e.idx] = Vector2(
    x: float32(rand(-120.0..120.0)),
    y: float32(rand(-120.0..120.0)))
  e

proc spawnCoin(w: var World, atlas: Atlas, map: Tilemap) =
  ## A coin that expires on its own unless somebody picks it up first.
  let e = w.spawn({ckPosition, ckSprite, ckLifetime, ckCollider,
                   ckPickup})
  w.sprites[e.idx] = initAnimSprite(atlas, "coin_anim", scale)
  w.colliders[e.idx] = Collider(
    size: Vector2(x: w.sprites[e.idx].width, y: w.sprites[e.idx].height),
    layer: lyPickup)
  w.pickupKinds[e.idx] = pkCoin
  w.positions[e.idx] = map.randomFloorPos()
  w.lifetimes[e.idx] = float32(rand(2.0..6.0))

proc spawnKey(w: var World, atlas: Atlas, pos: Vector2) =
  ## The seal-dissolving flask. Persistent: no lifetime, it waits.
  let e = w.spawn({ckPosition, ckSprite, ckCollider, ckPickup})
  w.sprites[e.idx] = initStaticSprite(atlas, "flask_big_yellow", scale)
  w.colliders[e.idx] = Collider(
    size: Vector2(x: w.sprites[e.idx].width, y: w.sprites[e.idx].height),
    layer: lyPickup)
  w.pickupKinds[e.idx] = pkKey
  w.positions[e.idx] = pos

proc swingSword(w: var World, atlas: Atlas, player: Entity) =
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
    y: px.y + 12)
  w.colliders[e.idx] = Collider(
    offset: Vector2(x: -12, y: -12),
    size: Vector2(x: w.sprites[e.idx].width + 24,
                  y: w.sprites[e.idx].height + 24),
    layer: lyPlayerAttack, hits: {lyEnemy})
  w.contactDamages[e.idx] = ContactDamage(amount: 1, knockback: 600)
  w.lifetimes[e.idx] = 0.15

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
                            Vector2(x: 32, y: 56)

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
  var world = World()
  var knight = world.populateFloor(crypt, atlas, floorNum, carryHp = 6)

  var cam = makeCamera(Vector2(x: screenWidth, y: screenHeight))
  cam.target = crypt.roomCenter(crypt.startRoom)

  var coinTimer: float32 = 0
  var coinsCollected = 0
  var kills = 0
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
    coinTimer -= dt
    if coinTimer <= 0:
      coinTimer = 0.5
      world.spawnCoin(atlas, crypt.map)
    attackCooldown -= dt
    if wasPressed(aAttack) and attackCooldown <= 0:
      attackCooldown = attackCooldownTime
      world.swingSword(atlas, knight)
    world.playerInputSystem(playerSpeed)
    world.aiSystem(knight)
    world.healthSystem(dt)
    world.movementSystem(crypt.map, dt, dbg.noclip)
    world.contactSystem()
    world.damageSystem()
    for spot in world.deathSystem():
      inc kills
      let d = world.spawn({ckPosition, ckSprite, ckLifetime})
      world.sprites[d.idx] = initStaticSprite(atlas, "skull", scale)
      world.positions[d.idx] = spot
      world.lifetimes[d.idx] = 4
    if world.healths[knight.idx].hp <= 0:
      # Death proper arrives with Chapter 13's state machine; for now
      # the crypt is merciful and sends him back to this floor's start.
      world.healths[knight.idx].hp = world.healths[knight.idx].maxHp
      world.healths[knight.idx].invuln = 1.5
      world.positions[knight.idx] = crypt.roomCenter(crypt.startRoom) -
                                    Vector2(x: 32, y: 56)
    for kind in world.pickupSystem():
      case kind
      of pkCoin: inc coinsCollected
      of pkKey: crypt.unlock()
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
    dbg.drawWorld(world)
    endMode2D()
    dbg.drawPanel(world, cam)
    let hp = world.healths[knight.idx]
    drawText("floor: " & $floorNum, 10, 40, 20, LightGray)
    drawText("hp: " & $hp.hp & "/" & $hp.maxHp, 10, 70, 20, Red)
    drawText("coins: " & $coinsCollected, 10, 100, 20, Gold)
    drawText(if crypt.isLocked: "the stairs are sealed"
             else: "the way down is open", 10, 130, 20,
             if crypt.isLocked: Gold else: Green)
    drawFPS(10, 10)
    endDrawing()

main()

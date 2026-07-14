## Chapter 9: the crypt fights back. Critters became enemies with
## health, chase AI, and contact damage; the knight got hit points,
## i-frames, knockback, and a sword (Space or J). The sword is not a
## special case anywhere: it is an entity with a collider, a damage
## component, and 0.15 seconds to live.

import std/random
import raylib, raymath
import camera, debug, ecs, input, resources, sprites, systems, tilemap

const
  screenWidth = 800
  screenHeight = 450
  playerSpeed = 170        # px/s; the crypt is large and life is short
  attackCooldownTime = 0.35
  backgroundColor = Color(r: 24, g: 20, b: 37, a: 255)
  atlasDir = "assets/0x72_DungeonTilesetII_v1.7/"

type
  EnemyStats = object
    ## An archetype is data: which art, how tough, how fast, how far
    ## it can smell you.
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

const cryptMap = """
################
#..............#
#..............#   ##########################
#..............#   #........................#
#..............#   #........................#
#..............#####........................#
#...........................................#
#...........................................#
#..............#####........................#
#..............#   #........................#
#..............#   #........................#
#..............#   #........................#
#..............#   #........................#
#########..#####   #........................#
        #..#       #........................#
        #..#       #........................#
     ####..####    #........................#
     #........#    #........................#
     #........#    #........................#
     #........#    #........................#
     #........#    #........................#
     #........#    #........................#
     #........#    ##########################
     #........#
     ##########"""

proc spawnEnemy(w: var World, atlas: Atlas,
                map: Tilemap): Entity {.discardable.} =
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
  w.positions[e.idx] = map.randomFloorPos()
  w.velocities[e.idx] = Vector2(
    x: float32(rand(-60.0..60.0)),
    y: float32(rand(-60.0..60.0)))
  e

proc spawnCoin(w: var World, atlas: Atlas, map: Tilemap) =
  ## A coin that expires on its own unless somebody picks it up first.
  let e = w.spawn({ckPosition, ckSprite, ckLifetime, ckCollider})
  w.sprites[e.idx] = initAnimSprite(atlas, "coin_anim", scale)
  w.colliders[e.idx] = Collider(
    size: Vector2(x: w.sprites[e.idx].width, y: w.sprites[e.idx].height),
    layer: lyPickup)
  w.positions[e.idx] = map.randomFloorPos()
  w.lifetimes[e.idx] = float32(rand(2.0..6.0))

proc swingSword(w: var World, atlas: Atlas, player: Entity) =
  ## The sword: an entity with a sprite, a hitbox slightly bigger than
  ## the blade, one point of damage, and 0.15 seconds to live. It
  ## appears on whichever side the knight is facing.
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
  w.contactDamages[e.idx] = ContactDamage(amount: 1, knockback: 300)
  w.lifetimes[e.idx] = 0.15

proc main =
  randomize()
  setConfigFlags(flags(WindowHighdpi))
  initWindow(screenWidth, screenHeight, "Crypt of Nimrod")
  defer: closeWindow()
  setTargetFPS(60)

  let atlas = loadAtlas(
    atlasDir & "0x72_DungeonTilesetII_v1.7.png",
    atlasDir & "tile_list_v1.7")
  let map = parseMap(cryptMap)
  let skin = makeSkin(atlas)

  var world = World()

  let knightStart = Vector2(x: 7*tileSize, y: 6*tileSize)
  let knight = world.spawn({ckPosition, ckVelocity, ckSprite, ckActor,
                            ckPlayer, ckCollider, ckHealth})
  world.sprites[knight.idx] = initAnimSprite(atlas, "knight_m_idle_anim", scale)
  world.actors[knight.idx] = Actor(idleAnim: "knight_m_idle_anim",
                                   runAnim: "knight_m_run_anim")
  world.colliders[knight.idx] = feetCollider(
    world.sprites[knight.idx], lyPlayer, hits = {lyPickup})
  world.healths[knight.idx] = Health(hp: 6, maxHp: 6, invulnTime: 0.8)
  world.positions[knight.idx] = knightStart

  for _ in 1..10:
    world.spawnEnemy(atlas, map)

  echo world.dump(knight)       # the echo test: any entity, reassembled

  var cam = makeCamera(Vector2(x: screenWidth, y: screenHeight))
  cam.target = world.positions[knight.idx]   # start on the knight, no glide

  var coinTimer: float32 = 0
  var coinsCollected = 0
  var kills = 0
  var attackCooldown: float32 = 0
  var dbg = initDebug()

  while not windowShouldClose():
    # --- Update ---
    dbg.update()
    let dt = getFrameTime()*dbg.timeScale
    if dbg.enabled:                # god keys that need main's context
      if isKeyPressed(T):
        world.positions[knight.idx] = mouseWorld(cam)
      if isKeyPressed(E):
        let e = world.spawnEnemy(atlas, map)
        world.positions[e.idx] = mouseWorld(cam)
    coinTimer -= dt
    if coinTimer <= 0:
      coinTimer = 0.5
      world.spawnCoin(atlas, map)
    attackCooldown -= dt
    if wasPressed(aAttack) and attackCooldown <= 0:
      attackCooldown = attackCooldownTime
      world.swingSword(atlas, knight)
    world.playerInputSystem(playerSpeed)
    world.aiSystem(knight)
    world.healthSystem(dt)
    world.movementSystem(map, dt, dbg.noclip)
    world.contactSystem()
    world.damageSystem()
    for spot in world.deathSystem():
      inc kills
      let d = world.spawn({ckPosition, ckSprite, ckLifetime})
      world.sprites[d.idx] = initStaticSprite(atlas, "skull", scale)
      world.positions[d.idx] = spot
      world.lifetimes[d.idx] = 4
    if world.healths[knight.idx].hp <= 0:
      # Death proper arrives with the state machine in Chapter 13; for
      # now the crypt is merciful and sends him back to the entrance.
      world.healths[knight.idx].hp = world.healths[knight.idx].maxHp
      world.healths[knight.idx].invuln = 1.5
      world.positions[knight.idx] = knightStart
    coinsCollected += world.pickupSystem()
    world.actorAnimSystem(atlas)
    world.animationSystem(dt)
    world.lifetimeSystem(dt)
    # The camera watches the knight's center, clamped to the map,
    # zoomed to compensate for display scaling.
    cam.adaptToDpi(Vector2(x: screenWidth, y: screenHeight))
    let knightCenter = world.positions[knight.idx] + Vector2(
      x: world.sprites[knight.idx].width/2,
      y: world.sprites[knight.idx].height/2)
    cam.follow(knightCenter, map.pixelSize, dt)

    # --- Draw ---
    beginDrawing()
    clearBackground(backgroundColor)
    beginMode2D(cam)               # world space: shifted by the camera
    map.draw(atlas, skin)
    world.drawSystem(atlas)
    dbg.drawWorld(world)           # collider boxes, when enabled
    endMode2D()                    # back to screen space for the HUD
    dbg.drawPanel(world, cam)
    let hp = world.healths[knight.idx]
    drawText("hp: " & $hp.hp & "/" & $hp.maxHp, 10, 40, 20, Red)
    drawText("coins: " & $coinsCollected, 10, 70, 20, Gold)
    drawText("kills: " & $kills, 10, 100, 20, LightGray)
    drawFPS(10, 10)
    endDrawing()

main()

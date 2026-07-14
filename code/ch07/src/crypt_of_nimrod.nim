## Chapter 7: masonry gets respected. Everything with a collider stops
## at walls and slides along them, critters ricochet off the actual
## architecture instead of the map's bounding box, and the knight
## collects coins by walking into them (the first layer-filtered
## entity-to-entity contact).

import std/random
import raylib, raymath
import camera, ecs, resources, sprites, systems, tilemap

const
  screenWidth = 1600
  screenHeight = 900
  playerSpeed = 340        # px/s; the crypt is large and life is short
  backgroundColor = Color(r: 24, g: 20, b: 37, a: 255)
  atlasDir = "assets/0x72_DungeonTilesetII_v1.7/"
  critterNames = ["goblin", "skelet", "imp", "chort", "ogre"]

  # The crypt, drawn in the finest of level editors. Three rooms:
  # the entrance hall (top left), the great hall (right), and a
  # small vault (bottom), joined by corridors.
  cryptMap = """
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

proc spawnCritter(w: var World, atlas: Atlas, map: Tilemap) =
  ## A random monster on a random floor tile, bouncing off walls.
  let e = w.spawn({ckPosition, ckVelocity, ckSprite, ckActor,
                   ckCollider, ckBounce})
  let name = critterNames[rand(critterNames.high)]
  w.sprites[e.idx] = initAnimSprite(atlas, name & "_idle_anim", scale)
  w.actors[e.idx] = Actor(idleAnim: name & "_idle_anim",
                          runAnim: name & "_run_anim")
  w.colliders[e.idx] = feetCollider(w.sprites[e.idx], lyEnemy)
  w.positions[e.idx] = map.randomFloorPos()
  w.velocities[e.idx] = Vector2(
    x: float32(rand(-150.0..150.0)),
    y: float32(rand(-120.0..120.0)))

proc spawnCoin(w: var World, atlas: Atlas, map: Tilemap) =
  ## A coin that expires on its own unless somebody picks it up first.
  let e = w.spawn({ckPosition, ckSprite, ckLifetime, ckCollider})
  w.sprites[e.idx] = initAnimSprite(atlas, "coin_anim", scale)
  # Coins use their whole box: they're small and meant to be touched.
  w.colliders[e.idx] = Collider(
    size: Vector2(x: w.sprites[e.idx].width, y: w.sprites[e.idx].height),
    layer: lyPickup)
  w.positions[e.idx] = map.randomFloorPos()
  w.lifetimes[e.idx] = float32(rand(2.0..6.0))

proc main =
  randomize()
  setConfigFlags(flags(WindowHighdpi))
  initWindow(screenWidth, screenHeight, "Crypt of Nimrod")
  defer: closeWindow()
  setTargetFPS(60)

  let atlas = loadAtlas(
    atlasDir & "0x72_DungeonTilesetII_v1.7.png",
    atlasDir & "tile_list_v1.7")
  let map = parseMap(atlas, cryptMap)

  var world = World()

  # The knight: his hits set is what makes coins collectable.
  let knight = world.spawn({ckPosition, ckVelocity, ckSprite,
                            ckActor, ckPlayer, ckCollider})
  world.sprites[knight.idx] = initAnimSprite(atlas, "knight_m_idle_anim", scale)
  world.actors[knight.idx] = Actor(idleAnim: "knight_m_idle_anim",
                                   runAnim: "knight_m_run_anim")
  world.colliders[knight.idx] = feetCollider(
    world.sprites[knight.idx], lyPlayer, hits = {lyPickup})
  world.positions[knight.idx] = Vector2(x: 7*tileSize, y: 6*tileSize)

  for _ in 1..10:
    world.spawnCritter(atlas, map)

  echo world.dump(knight)       # the echo test: any entity, reassembled

  var cam = makeCamera(Vector2(x: screenWidth, y: screenHeight))
  cam.target = world.positions[knight.idx]   # start on the knight, no glide

  var coinTimer: float32 = 0
  var coinsCollected = 0

  while not windowShouldClose():
    # --- Update ---
    let dt = getFrameTime()
    coinTimer -= dt
    if coinTimer <= 0:
      coinTimer = 0.5
      world.spawnCoin(atlas, map)
    world.playerInputSystem(playerSpeed)
    world.movementSystem(map, dt)
    world.contactSystem()
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
    map.draw(atlas)
    world.drawSystem(atlas)
    endMode2D()                    # back to screen space for the HUD
    drawText("coins: " & $coinsCollected, 10, 40, 20, Gold)
    drawText("entities: " & $world.entityCount, 10, 70, 20, LightGray)
    drawFPS(10, 10)
    endDrawing()

main()

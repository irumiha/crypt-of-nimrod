## Chapter 6: the crypt gets a shape. The world is a tilemap parsed
## from the ASCII art below, bigger than the window, and a camera
## follows the knight through it. Nobody collides with anything yet;
## the knight is a ghost in his own crypt until Chapter 7.

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
  ## A random monster on a random floor tile, drifting in a random
  ## direction, with idle/run animations wired up.
  let e = w.spawn({ckPosition, ckVelocity, ckSprite, ckActor})
  let name = critterNames[rand(critterNames.high)]
  w.sprites[e.idx] = initAnimSprite(atlas, name & "_idle_anim", scale)
  w.actors[e.idx] = Actor(idleAnim: name & "_idle_anim",
                          runAnim: name & "_run_anim")
  w.positions[e.idx] = map.randomFloorPos()
  w.velocities[e.idx] = Vector2(
    x: float32(rand(-150.0..150.0)),
    y: float32(rand(-120.0..120.0)))

proc spawnCoin(w: var World, atlas: Atlas, map: Tilemap) =
  ## A coin that expires on its own, somewhere on the floor.
  let e = w.spawn({ckPosition, ckSprite, ckLifetime})
  w.sprites[e.idx] = initAnimSprite(atlas, "coin_anim", scale)
  w.positions[e.idx] = map.randomFloorPos()
  w.lifetimes[e.idx] = float32(rand(1.0..4.0))

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

  # The knight starts in the entrance hall.
  let knight = world.spawn({ckPosition, ckVelocity, ckSprite,
                            ckActor, ckPlayer})
  world.sprites[knight.idx] = initAnimSprite(atlas, "knight_m_idle_anim", scale)
  world.actors[knight.idx] = Actor(idleAnim: "knight_m_idle_anim",
                                   runAnim: "knight_m_run_anim")
  world.positions[knight.idx] = Vector2(x: 7*tileSize, y: 6*tileSize)

  for _ in 1..10:
    world.spawnCritter(atlas, map)

  var cam = makeCamera(Vector2(x: screenWidth, y: screenHeight))
  cam.target = world.positions[knight.idx]   # start on the knight, no glide

  var coinTimer: float32 = 0

  while not windowShouldClose():
    # --- Update ---
    let dt = getFrameTime()
    coinTimer -= dt
    if coinTimer <= 0:
      coinTimer = 0.5
      world.spawnCoin(atlas, map)
    world.playerInputSystem(playerSpeed)
    world.movementSystem(dt)
    world.bounceSystem(map.pixelSize)
    world.actorAnimSystem(atlas)
    world.animationSystem(dt)
    world.lifetimeSystem(dt)
    # The camera watches the knight's center, clamped to the map.
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
    drawText("entities: " & $world.entityCount, 10, 40, 20, LightGray)
    drawFPS(10, 10)
    endDrawing()

main()

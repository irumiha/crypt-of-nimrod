## Chapter 5: the knight walks. An action map turns held keys into a
## movement vector, a player-tagged entity picks it up as velocity, and
## an actor system switches everyone between idle and run animations
## and faces them where they're going — critters included.

import std/random
import raylib
import ecs, resources, sprites, systems

const
  screenWidth = 800
  screenHeight = 450
  scale = 2                # 16px art, 32px on screen
  tileSize = 16*scale
  playerSpeed = 170        # px/s; the crypt is large and life is short
  backgroundColor = Color(r: 24, g: 20, b: 37, a: 255)
  atlasDir = "assets/0x72_DungeonTilesetII_v1.7/"
  # Every name here must exist in the atlas as <name>_idle_anim and
  # <name>_run_anim; a bad one fails loudly at spawn.
  critterNames = ["goblin", "skelet", "imp", "chort", "ogre"]

proc spawnCritter(w: var World, atlas: Atlas) =
  ## A random monster somewhere on the floor, drifting in a random
  ## direction, with idle/run animations wired up.
  let e = w.spawn({ckPosition, ckVelocity, ckSprite, ckActor})
  let name = critterNames[rand(critterNames.high)]
  w.sprites[e.idx] = initAnimSprite(atlas, name & "_idle_anim", scale)
  w.actors[e.idx] = Actor(idleAnim: name & "_idle_anim",
                          runAnim: name & "_run_anim")
  w.positions[e.idx] = Vector2(
    x: float32(rand(tileSize..(screenWidth - 2*tileSize))),
    y: float32(rand(tileSize..(screenHeight - 2*tileSize))))
  w.velocities[e.idx] = Vector2(
    x: float32(rand(-75.0..75.0)),
    y: float32(rand(-60.0..60.0)))

proc spawnCoin(w: var World, atlas: Atlas) =
  ## A coin that expires on its own: same spawn shape as a critter,
  ## but with Lifetime instead of Velocity in the parts list.
  let e = w.spawn({ckPosition, ckSprite, ckLifetime})
  w.sprites[e.idx] = initAnimSprite(atlas, "coin_anim", scale)
  w.positions[e.idx] = Vector2(
    x: float32(rand(tileSize..(screenWidth - 2*tileSize))),
    y: float32(rand(tileSize..(screenHeight - 2*tileSize))))
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

  # The floor: one variant per cell, rolled once at startup (Chapter 3).
  const cols = screenWidth div tileSize
  const rows = screenHeight div tileSize + 1
  var floorTiles: seq[Rectangle]
  for i in 0 ..< cols*rows:
    let name = if rand(1.0) < 0.9: "floor_1"
               else: "floor_" & $rand(2..8)
    floorTiles.add(atlas.rect(name))

  var world = World()

  # The knight is now a player: the tag routes input to him, the
  # Velocity lets movement carry him, the Actor swaps his animations.
  let knight = world.spawn({ckPosition, ckVelocity, ckSprite,
                            ckActor, ckPlayer})
  world.sprites[knight.idx] = initAnimSprite(atlas, "knight_m_idle_anim", scale)
  world.actors[knight.idx] = Actor(idleAnim: "knight_m_idle_anim",
                                   runAnim: "knight_m_run_anim")
  world.positions[knight.idx] = Vector2(
    x: (screenWidth - 16*scale)/2,
    y: (screenHeight - 28*scale)/2)

  for _ in 1..10:
    world.spawnCritter(atlas)

  echo world.dump(knight)       # the echo test: any entity, reassembled

  var coinTimer: float32 = 0

  while not windowShouldClose():
    # --- Update ---
    let dt = getFrameTime()
    coinTimer -= dt
    if coinTimer <= 0:
      coinTimer = 0.5
      world.spawnCoin(atlas)
    world.playerInputSystem(playerSpeed)
    world.movementSystem(dt)
    world.bounceSystem(Vector2(x: screenWidth, y: screenHeight))
    world.actorAnimSystem(atlas)
    world.animationSystem(dt)
    world.lifetimeSystem(dt)

    # --- Draw ---
    beginDrawing()
    clearBackground(backgroundColor)
    for i, rect in floorTiles:
      let col = i mod cols
      let row = i div cols
      let dest = Rectangle(
        x: float32(col*tileSize), y: float32(row*tileSize),
        width: tileSize, height: tileSize)
      drawTexture(atlas.texture, rect, dest, Vector2(x: 0, y: 0), 0, White)
    world.drawSystem(atlas)
    drawText("entities: " & $world.entityCount, 10, 40, 20, LightGray)
    drawFPS(10, 10)
    endDrawing()

main()

import std/random
import raylib
import resources, sprites

const
  screenWidth = 1600
  screenHeight = 900
  scale = 4                # 16px art, 64px on screen
  tileSize = 16*scale
  backgroundColor = Color(r: 24, g: 20, b: 37, a: 255)
  atlasDir = "assets/0x72_DungeonTilesetII_v1.7/"

proc main =
  randomize()
  setConfigFlags(flags(WindowHighdpi))
  initWindow(screenWidth, screenHeight, "Crypt of Nimrod")
  defer: closeWindow()
  setTargetFPS(60)

  let atlas = loadAtlas(
    atlasDir & "0x72_DungeonTilesetII_v1.7.png",
    atlasDir & "tile_list_v1.7")

  # The floor: one variant per cell, rolled once at startup.
  const cols = screenWidth div tileSize
  const rows = screenHeight div tileSize + 1
  var floorTiles: seq[Rectangle]
  for i in 0 ..< cols*rows:
    let name = if rand(1.0) < 0.9: "floor_1"
               else: "floor_" & $rand(2..8)
    floorTiles.add(atlas.rect(name))

  var knight = initAnimSprite(atlas, "knight_m_idle_anim")
  let knightPos = Vector2(
    x: (screenWidth - 16*scale)/2,
    y: (screenHeight - 28*scale)/2)

  var coin = initAnimSprite(atlas, "coin_anim")

  while not windowShouldClose():
    # --- Update ---
    let dt = getFrameTime()
    knight.update(dt)
    coin.update(dt)

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
    atlas.draw("chest_empty_open_anim_f0",
      Vector2(x: knightPos.x - 3*tileSize, y: knightPos.y + tileSize), scale)
    atlas.draw("skull",
      Vector2(x: knightPos.x + 2.5*tileSize, y: knightPos.y + 1.5*tileSize),
      scale)
    coin.draw(atlas,
      Vector2(x: knightPos.x - 1.7*tileSize, y: knightPos.y + 1.3*tileSize),
      scale)
    knight.draw(atlas, knightPos, scale)
    drawFPS(10, 10)
    endDrawing()

main()

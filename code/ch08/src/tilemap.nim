## The crypt as data: a grid of tile kinds parsed from ASCII art. Your
## text editor is the level editor; a `#` is a wall, a `.` is floor,
## anything else is the void outside.
##
## Changed in Chapter 8: the map no longer touches the atlas. Pure
## world data lives here (usable in headless tests, no GPU required);
## how it looks lives in TileSkin, built from the atlas by whoever
## actually intends to draw.

import std/[random, strutils]
import raylib
import resources

const
  scale* = 2               # 16px art, 32px on screen
  tileSize* = 16*scale
  # Tint multiplies the texture's colors; a gray-purple darkens the
  # brick into a believable wall top without extra art.
  wallTopTint = Color(r: 110, g: 100, b: 130, a: 255)

type
  TileKind* = enum
    tkVoid, tkFloor, tkWall

  Tilemap* = object
    width*, height*: int32   # in tiles
    tiles: seq[TileKind]     # row-major, width*height entries
    floorVariants: seq[int32]  # 1..8, rolled once per cell

  TileSkin* = object
    ## The map's looks: which atlas regions the tile kinds draw with.
    ## Kept apart from Tilemap so the world data stays GPU-free.
    floors*: array[1..8, Rectangle]
    wall*: Rectangle

proc parseMap*(ascii: string): Tilemap =
  ## Builds a map from ASCII art. Lines may have ragged lengths; the
  ## map is as wide as the longest one and short lines pad with void.
  ## Floor variants are rolled here, once per cell, weighted toward
  ## the plain tile so cracks read as wear.
  let lines = ascii.strip(chars = {'\n'}).splitLines
  result.height = int32(lines.len)
  for line in lines:
    result.width = max(result.width, int32(line.len))
  for y in 0 ..< result.height:
    for x in 0 ..< result.width:
      let ch = if x < lines[y].len: lines[y][x] else: ' '
      result.tiles.add(
        case ch
        of '#': tkWall
        of '.': tkFloor
        else: tkVoid)
      result.floorVariants.add(
        if rand(1.0) < 0.9: 1'i32 else: int32(rand(2..8)))

proc makeSkin*(atlas: Atlas): TileSkin =
  ## Resolves the tile art once, at load time.
  for i in 1..8:
    result.floors[i] = atlas.rect("floor_" & $i)
  result.wall = atlas.rect("wall_mid")

proc tileAt*(m: Tilemap, x, y: int32): TileKind =
  ## The tile at a grid coordinate; everything outside the map is
  ## void. (Chapter 7's collision checks lean on that.)
  if x < 0 or y < 0 or x >= m.width or y >= m.height: tkVoid
  else: m.tiles[y*m.width + x]

proc pixelSize*(m: Tilemap): Vector2 =
  ## The map's size in world pixels (for camera clamping and bounds).
  Vector2(x: float32(m.width*tileSize), y: float32(m.height*tileSize))

proc randomFloorPos*(m: Tilemap): Vector2 =
  ## The top-left corner of a random floor tile, for spawning things
  ## somewhere sensible. Loops until it hits floor, which on any sane
  ## map takes a couple of tries.
  while true:
    let x = int32(rand(m.width - 1))
    let y = int32(rand(m.height - 1))
    if m.tileAt(x, y) == tkFloor:
      return Vector2(x: float32(x*tileSize), y: float32(y*tileSize))

proc draw*(m: Tilemap, atlas: Atlas, skin: TileSkin) =
  ## Draws the whole map in world coordinates; the camera decides
  ## what's on screen. Void cells stay undrawn (the background shows).
  for y in 0'i32 ..< m.height:
    for x in 0'i32 ..< m.width:
      let i = y*m.width + x
      let dest = Rectangle(
        x: float32(x*tileSize), y: float32(y*tileSize),
        width: tileSize, height: tileSize)
      case m.tiles[i]
      of tkFloor:
        drawTexture(atlas.texture, skin.floors[m.floorVariants[i]],
                    dest, Vector2(x: 0, y: 0), 0, White)
      of tkWall:
        # A wall cell with floor directly below it is a front face and
        # draws at full brightness; every other wall cell is a "top"
        # and draws darkened via the tint parameter.
        let tint = if m.tileAt(x, y + 1) == tkFloor: White
                   else: wallTopTint
        drawTexture(atlas.texture, skin.wall, dest,
                    Vector2(x: 0, y: 0), 0, tint)
      of tkVoid:
        discard

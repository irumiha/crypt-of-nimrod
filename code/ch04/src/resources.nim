import std/[strutils, tables]
import raylib

type
  Atlas* = object
    ## One texture and a name -> region index, loaded from the
    ## tile list that ships with the art pack.
    texture*: Texture2D
    rects: Table[string, Rectangle]

proc loadAtlas*(imagePath, indexPath: string): Atlas =
  result.texture = loadTexture(imagePath)
  for line in readFile(indexPath).splitLines:
    # Each line: name x y width height
    let parts = line.splitWhitespace
    if parts.len >= 5:
      result.rects[parts[0]] = Rectangle(
        x: parseFloat(parts[1]).float32,
        y: parseFloat(parts[2]).float32,
        width: parseFloat(parts[3]).float32,
        height: parseFloat(parts[4]).float32)

proc rect*(atlas: Atlas, name: string): Rectangle =
  ## The region of a named sprite. Unknown names are a programmer error.
  doAssert name in atlas.rects, "unknown sprite: " & name
  atlas.rects[name]

proc frames*(atlas: Atlas, name: string): seq[Rectangle] =
  ## Collects name_f0, name_f1, ... into an animation's frame list.
  var i = 0
  while atlas.rects.hasKey(name & "_f" & $i):
    result.add(atlas.rects[name & "_f" & $i])
    inc i
  doAssert result.len > 0, "no frames for: " & name

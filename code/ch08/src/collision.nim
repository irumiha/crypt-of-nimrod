## Collision with the world's masonry: solid-tile overlap tests and
## axis-separated move-and-slide.
##
## The tilemap needs no spatial index because it is one: which tiles a
## box overlaps is integer division, and each check touches only the
## handful of cells under the box.

import raylib
import ecs, tilemap

const solidTiles = {tkWall, tkVoid}
  # Void is solid on purpose: nothing walks off the edge of the world.

proc overlapsSolid*(m: Tilemap, r: Rectangle): bool =
  ## Whether a world-space box overlaps any wall or void tile. Scans
  ## just the tile range under the box (usually 1 to 4 cells).
  let x0 = int32(r.x) div tileSize
  let y0 = int32(r.y) div tileSize
  let x1 = int32(r.x + r.width - 1) div tileSize
  let y1 = int32(r.y + r.height - 1) div tileSize
  for ty in y0..y1:
    for tx in x0..x1:
      if m.tileAt(tx, ty) in solidTiles:
        return true

proc moveAndSlide*(m: Tilemap, pos: var Vector2, col: Collider,
                   delta: Vector2): tuple[x, y: bool] =
  ## Moves a collider by delta, one axis at a time. When an axis hits
  ## a solid tile, the position snaps flush against it and that axis
  ## reports a hit; the other axis still moves, which is what makes
  ## walls slideable instead of sticky. Returns which axes hit.
  # --- X axis ---
  pos.x += delta.x
  var r = Rectangle(x: pos.x + col.offset.x, y: pos.y + col.offset.y,
                    width: col.size.x, height: col.size.y)
  if m.overlapsSolid(r):
    result.x = true
    if delta.x > 0:   # moving right: flush against the tile's left edge
      let edge = (int32(r.x + r.width - 1) div tileSize)*tileSize
      pos.x = float32(edge) - col.size.x - col.offset.x
    elif delta.x < 0: # moving left: flush against the tile's right edge
      let edge = (int32(r.x) div tileSize + 1)*tileSize
      pos.x = float32(edge) - col.offset.x
  # --- Y axis ---
  pos.y += delta.y
  r = Rectangle(x: pos.x + col.offset.x, y: pos.y + col.offset.y,
                width: col.size.x, height: col.size.y)
  if m.overlapsSolid(r):
    result.y = true
    if delta.y > 0:
      let edge = (int32(r.y + r.height - 1) div tileSize)*tileSize
      pos.y = float32(edge) - col.size.y - col.offset.y
    elif delta.y < 0:
      let edge = (int32(r.y) div tileSize + 1)*tileSize
      pos.y = float32(edge) - col.offset.y

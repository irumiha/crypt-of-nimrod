## The floor generator: an Isaac-style grid of screen-sized rooms.
##
## A seeded random walk picks which grid cells become rooms, every
## pair of adjacent rooms gets a doorway, the farthest room gets the
## stairs down (sealed), and the key to the seal goes in the farthest
## ordinary room. Everything is carved into a plain Tilemap, so all of
## chapters 6-9 keeps working untouched, and the whole module runs
## headless (the tests lean on that).
##
## Determinism is the point of taking a seed: the same seed always
## builds the same floor, which makes bugs reproducible and daily
## challenge runs possible. Chapter 2 promised this payoff.

import std/[deques, random]
import raylib
import tilemap

const
  roomCols* = 4        # the floor is a 4x3 grid of potential rooms
  roomRows* = 3
  roomW* = 25          # tiles per room: exactly one 800x450 screen
  roomH* = 14

type
  Room* = object
    gx*, gy*: int32    # which grid cell this room occupies
    depth*: int32      # steps from the start room, filled by BFS

  Dungeon* = object
    map*: Tilemap
    rooms*: seq[Room]
    startRoom*: int
    keyRoom*: int      # holds the seal-dissolving flask
    stairsRoom*: int   # holds the stairs down, behind sealed doors
    sealed: seq[tuple[x, y: int32]]

proc roomIndexAt(d: Dungeon, gx, gy: int32): int =
  ## The room occupying a grid cell, or -1.
  result = -1
  for i, r in d.rooms:
    if r.gx == gx and r.gy == gy:
      return i

proc carveRoom(m: var Tilemap, room: Room) =
  ## One cell: walls on the perimeter, floor inside.
  let ox = room.gx*roomW
  let oy = room.gy*roomH
  for y in 0'i32 ..< roomH:
    for x in 0'i32 ..< roomW:
      let border = x == 0 or y == 0 or x == roomW - 1 or y == roomH - 1
      m.setTile(ox + x, oy + y, if border: tkWall else: tkFloor)

proc carveDoor(d: var Dungeon, a, b: Room, seal: bool) =
  ## A 2-tile-wide opening through the double wall between two
  ## adjacent rooms; sealed doors get tkSealed instead of floor and
  ## are remembered so unlock() can dissolve them.
  var spots: seq[tuple[x, y: int32]]
  if a.gy == b.gy:               # side by side: carve through 2 columns
    let left = min(a.gx, b.gx)
    let cols = [left*roomW + roomW - 1, left*roomW + roomW]
    let midY = a.gy*roomH + roomH div 2
    for c in cols:
      spots.add((int32(c), int32(midY - 1)))
      spots.add((int32(c), int32(midY)))
  else:                          # stacked: carve through 2 rows
    let top = min(a.gy, b.gy)
    let rows = [top*roomH + roomH - 1, top*roomH + roomH]
    let midX = a.gx*roomW + roomW div 2
    for r in rows:
      spots.add((int32(midX - 1), int32(r)))
      spots.add((int32(midX), int32(r)))
  for (x, y) in spots:
    d.map.setTile(x, y, if seal: tkSealed else: tkFloor)
    if seal:
      d.sealed.add((x, y))

proc generate*(seed: int64, floorNum: int): Dungeon =
  ## Builds a whole floor from a seed. Same seed, same floor, every
  ## time, on every machine: the generator gets its own Rand instead
  ## of the global one precisely so nothing else can disturb it.
  var rng = initRand(seed)
  let targetRooms = min(6 + floorNum, roomCols*roomRows)

  # A random walk from the center claims grid cells.
  var taken: seq[Room]
  taken.add(Room(gx: roomCols div 2, gy: roomRows div 2))
  while taken.len < targetRooms:
    let origin = taken[rng.rand(taken.high)]
    let dirs = [(1'i32, 0'i32), (-1'i32, 0'i32), (0'i32, 1'i32),
                (0'i32, -1'i32)]
    let (dx, dy) = dirs[rng.rand(3)]
    let nx = origin.gx + dx
    let ny = origin.gy + dy
    if nx >= 0 and ny >= 0 and nx < roomCols and ny < roomRows:
      var exists = false
      for r in taken:
        if r.gx == nx and r.gy == ny:
          exists = true
      if not exists:
        taken.add(Room(gx: nx, gy: ny))

  result.rooms = taken
  result.map = initTilemap(int32(roomCols*roomW), int32(roomRows*roomH))
  for room in result.rooms:
    result.map.carveRoom(room)

  # BFS depths from the start room, over grid adjacency.
  result.startRoom = 0
  var queue = initDeque[int]()
  var seen = newSeq[bool](result.rooms.len)
  queue.addLast(0)
  seen[0] = true
  while queue.len > 0:
    let cur = queue.popFirst()
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
      let n = result.roomIndexAt(result.rooms[cur].gx + int32(dx),
                                 result.rooms[cur].gy + int32(dy))
      if n >= 0 and not seen[n]:
        seen[n] = true
        result.rooms[n].depth = result.rooms[cur].depth + 1
        queue.addLast(n)

  # The stairs hide in the deepest room; the key in the deepest room
  # that is neither the stairs nor the entrance.
  result.stairsRoom = 0
  for i, r in result.rooms:
    if r.depth > result.rooms[result.stairsRoom].depth:
      result.stairsRoom = i
  result.keyRoom = -1
  for i, r in result.rooms:
    if i != result.stairsRoom and i != result.startRoom and
        (result.keyRoom < 0 or r.depth > result.rooms[result.keyRoom].depth):
      result.keyRoom = i
  if result.keyRoom < 0:         # two-room floor: key sits at the start
    result.keyRoom = result.startRoom

  # Doorways between every pair of adjacent rooms; the stairs room's
  # doors are sealed until the key dissolves them.
  for i, a in result.rooms:
    for j, b in result.rooms:
      if j > i and abs(a.gx - b.gx) + abs(a.gy - b.gy) == 1:
        let seal = i == result.stairsRoom or j == result.stairsRoom
        result.carveDoor(a, b, seal)

  # The stairs themselves, center of their room.
  let sr = result.rooms[result.stairsRoom]
  result.map.setTile(sr.gx*roomW + roomW div 2,
                     sr.gy*roomH + roomH div 2, tkStairs)

proc unlock*(d: var Dungeon) =
  ## The key dissolves every sealed tile into ordinary floor.
  for (x, y) in d.sealed:
    d.map.setTile(x, y, tkFloor)
  d.sealed.setLen(0)

proc isLocked*(d: Dungeon): bool =
  d.sealed.len > 0

proc roomCenter*(d: Dungeon, room: int): Vector2 =
  ## The world-space center of a room (what the camera looks at).
  Vector2(
    x: float32(d.rooms[room].gx*roomW*tileSize) + roomW*tileSize/2,
    y: float32(d.rooms[room].gy*roomH*tileSize) + roomH*tileSize/2)

proc roomAt*(d: Dungeon, pos: Vector2): int =
  ## Which room a world position is in, or -1 for the void between.
  let gx = int32(pos.x) div (roomW*tileSize)
  let gy = int32(pos.y) div (roomH*tileSize)
  d.roomIndexAt(gx, gy)

proc randomPosIn*(d: Dungeon, room: int): Vector2 =
  ## A spot on a random interior tile of a room (for spawning).
  let r = d.rooms[room]
  let x = r.gx*roomW + 2 + int32(rand(roomW - 5))
  let y = r.gy*roomH + 2 + int32(rand(roomH - 5))
  Vector2(x: float32(x*tileSize), y: float32(y*tileSize))

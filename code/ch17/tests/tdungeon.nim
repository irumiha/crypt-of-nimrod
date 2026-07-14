## Headless tests for the floor generator: connectivity, determinism,
## and the lock-and-key contract. Generators are the most testable
## code in a game, and the easiest to break with an innocent tweak.

import std/unittest
import raylib
import dungeon, tilemap

proc tilesEqual(a, b: Tilemap): bool =
  if a.width != b.width or a.height != b.height:
    return false
  for y in 0'i32 ..< a.height:
    for x in 0'i32 ..< a.width:
      if a.tileAt(x, y) != b.tileAt(x, y):
        return false
  true

proc countTiles(m: Tilemap, kind: TileKind): int =
  for y in 0'i32 ..< m.height:
    for x in 0'i32 ..< m.width:
      if m.tileAt(x, y) == kind:
        inc result

suite "generation":
  test "the same seed builds the same floor, twice":
    check tilesEqual(generate(42, 1).map, generate(42, 1).map)

  test "different seeds build different floors":
    check not tilesEqual(generate(42, 1).map, generate(43, 1).map)

  test "every room is reachable from the start":
    # BFS depth 0 is only correct for the start room; everything else
    # reachable got a positive depth during generation's own BFS.
    for seed in 1..20:
      let d = generate(int64(seed), 2)
      for i, room in d.rooms:
        if i != d.startRoom:
          check room.depth > 0

  test "special rooms are distinct when the floor is big enough":
    for seed in 1..20:
      let d = generate(int64(seed), 2)   # floor 2: eight rooms
      check d.stairsRoom != d.startRoom
      check d.keyRoom != d.stairsRoom
      check d.keyRoom != d.startRoom

  test "room lookup inverts room centers":
    let d = generate(7, 1)
    for i in 0 ..< d.rooms.len:
      check d.roomAt(d.roomCenter(i)) == i

suite "the seal":
  test "stairs start sealed; the key dissolves exactly the seals":
    var d = generate(99, 1)
    check d.isLocked
    let seals = countTiles(d.map, tkSealed)
    check seals > 0
    let floors = countTiles(d.map, tkFloor)
    d.unlock()
    check not d.isLocked
    check countTiles(d.map, tkSealed) == 0
    check countTiles(d.map, tkFloor) == floors + seals

  test "there is exactly one staircase":
    for seed in 1..20:
      check countTiles(generate(int64(seed), 3).map, tkStairs) == 1

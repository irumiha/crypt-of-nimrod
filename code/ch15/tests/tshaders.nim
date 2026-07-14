## Chapter 15: what shader work can be tested without a GPU.
##
## The hover pick is rectangle math, so it gets ordinary tests. The
## shaders themselves are text files with rules we can hold them to:
## every *-330.fs must have a *-100.fs twin, and the twins must declare
## identical uniforms — a uniform added to one dialect and not the
## other is a bug that only the web build would ever report.

import std/[os, strutils, unittest]
import raylib
import ecs, systems

const shaderDir = currentSourcePath().parentDir() / ".." / "shaders"

proc uniformsOf(path: string): seq[string] =
  ## Every uniform declaration, in file order, comments dropped.
  for line in readFile(path).splitLines:
    let l = line.split("//")[0].strip
    if l.startsWith("uniform "):
      result.add(l)

proc spawnPickupAt(w: var World, pos: Vector2): Entity =
  result = w.spawn({ckPosition, ckCollider, ckPickup})
  w.positions[result.idx] = pos
  w.colliders[result.idx] = Collider(size: Vector2(x: 32, y: 32),
                                     layer: lyPickup)

suite "hover pick":
  test "finds the pickup under the point":
    var w: World
    let a = w.spawnPickupAt(Vector2(x: 100, y: 100))
    let b = w.spawnPickupAt(Vector2(x: 200, y: 100))
    w.hoverSystem(Vector2(x: 210, y: 110))
    check w.hovered == b.idx
    w.hoverSystem(Vector2(x: 110, y: 110))
    check w.hovered == a.idx

  test "empty space hovers nothing":
    var w: World
    discard w.spawnPickupAt(Vector2(x: 100, y: 100))
    w.hoverSystem(Vector2(x: 500, y: 500))
    check w.hovered == -1

  test "non-pickups are not hoverable":
    var w: World
    # A collider without ckPickup (an enemy, say) must not match.
    let e = w.spawn({ckPosition, ckCollider})
    w.positions[e.idx] = Vector2(x: 100, y: 100)
    w.colliders[e.idx] = Collider(size: Vector2(x: 32, y: 32),
                                  layer: lyEnemy)
    w.hoverSystem(Vector2(x: 110, y: 110))
    check w.hovered == -1

suite "shader sources":
  test "every 330 shader has a 100 twin with identical uniforms":
    var found = 0
    for path in walkFiles(shaderDir / "*-330.fs"):
      inc found
      let twin = path.replace("-330.fs", "-100.fs")
      check fileExists(twin)
      check uniformsOf(path) == uniformsOf(twin)
    check found == 2   # outline and crt, and a nudge to update this test

  test "dialect markers are in place":
    for path in walkFiles(shaderDir / "*.fs"):
      let src = readFile(path)
      if path.endsWith("-330.fs"):
        check src.startsWith("#version 330")
      else:
        check src.startsWith("#version 100")
        # WebGL 1 requires a default float precision; desktop GL
        # doesn't, so forgetting it here fails only in the browser.
        check "precision mediump float;" in src

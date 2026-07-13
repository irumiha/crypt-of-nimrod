import std/random
import raylib

type
  Ember* = object
    ## A plain value type: no `new`, no null, no ceremony.
    pos: Vector2
    vel: Vector2
    life: float32     # seconds remaining
    maxLife: float32

const emberColor = Color(r: 232, g: 193, b: 112, a: 255)

proc spawnEmber*(x, y: float32): Ember =
  ## A new ember somewhere near (x, y), drifting upward.
  let life = float32(rand(2.0..4.0))
  Ember(
    pos: Vector2(x: x + float32(rand(-160.0..160.0)), y: y),
    vel: Vector2(x: float32(rand(-25.0..25.0)),
                 y: float32(rand(-130.0.. -50.0))),
    life: life,
    maxLife: life)

proc update*(embers: var seq[Ember], dt: float32) =
  for e in embers.mitems:
    e.pos.x += e.vel.x*dt
    e.pos.y += e.vel.y*dt
    e.life -= dt
  # Compact away the dead: swap the last one in, shrink the seq.
  var i = 0
  while i < embers.len:
    if embers[i].life <= 0:
      embers[i] = embers[^1]
      embers.setLen(embers.len - 1)
    else:
      inc i

proc draw*(embers: seq[Ember]) =
  for e in embers:
    # Fade out as life runs down.
    let alpha = uint8(255*e.life/e.maxLife)
    drawCircle(int32(e.pos.x), int32(e.pos.y), 4,
      Color(r: emberColor.r, g: emberColor.g, b: emberColor.b, a: alpha))

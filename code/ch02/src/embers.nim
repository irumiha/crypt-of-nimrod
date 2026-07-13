## Golden embers drifting up around the title-screen crown.
##
## The first homegrown module, and a miniature of how the whole game
## will manage short-lived things: plain value objects in a seq,
## updated in place, removed by swap-and-shrink.

import std/random
import raylib

type
  Ember* = object
    ## A plain value type: no `new`, no null, no ceremony. Copying one
    ## copies it; nothing can hold a reference to it behind your back.
    pos: Vector2
    vel: Vector2
    life: float32     # seconds remaining
    maxLife: float32  # starting life, kept so draw can fade proportionally

const emberColor = Color(r: 232, g: 193, b: 112, a: 255)

proc spawnEmber*(x, y: float32): Ember =
  ## A new ember somewhere near (x, y), drifting upward with a
  ## randomized speed and lifespan.
  let life = float32(rand(2.0..4.0))
  Ember(
    pos: Vector2(x: x + float32(rand(-160.0..160.0)), y: y),
    # The space in `..  -50.0` is load-bearing: without it, `..-`
    # parses as a single (undefined) operator.
    vel: Vector2(x: float32(rand(-25.0..25.0)),
                 y: float32(rand(-130.0.. -50.0))),
    life: life,
    maxLife: life)

proc update*(embers: var seq[Ember], dt: float32) =
  ## Moves every ember and removes the expired ones. Takes the seq as
  ## `var` because it mutates it, and the signature says so.
  for e in embers.mitems:
    e.pos.x += e.vel.x*dt
    e.pos.y += e.vel.y*dt
    e.life -= dt
  # Compact away the dead: swap the last ember into the hole, shrink
  # the seq by one. No shifting, no allocation; order changes, which
  # embers don't mind. The same idiom despawns enemies later on.
  var i = 0
  while i < embers.len:
    if embers[i].life <= 0:
      embers[i] = embers[^1]
      embers.setLen(embers.len - 1)
    else:
      inc i

proc draw*(embers: seq[Ember]) =
  ## Draws each ember as a small circle, fading out as life runs down.
  for e in embers:
    let alpha = uint8(255*e.life/e.maxLife)
    drawCircle(int32(e.pos.x), int32(e.pos.y), 4,
      Color(r: emberColor.r, g: emberColor.g, b: emberColor.b, a: alpha))

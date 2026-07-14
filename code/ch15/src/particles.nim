## The particle system: the one subsystem in this game where data
## layout earns its keep, and the reason it is deliberately NOT part
## of the ECS. Particles arrive in the thousands, are updated by one
## narrow loop touching two or three fields, and never interact with
## anything, so entity identity, masks, and queries would be pure
## overhead. Plain parallel arrays (structure of arrays) it is.
##
## One rule inherited from Chapter 4's research: position and velocity
## stay together in one object. Splitting a Vector2 into separate x/y
## arrays doubles the memory streams and defeats vectorization.

import std/[math, random]
import raylib, raymath

type
  ParticleBody* = object
    pos*, vel*: Vector2

  Particles* = object
    ## Parallel arrays, one entry per particle, always in lockstep:
    ## index i means the same particle in every seq.
    bodies: seq[ParticleBody]
    life: seq[float32]
    maxLife: seq[float32]
    colors: seq[Color]

proc len*(p: Particles): int =
  p.bodies.len

proc body*(p: Particles, i: int): ParticleBody =
  ## Read access for inspection (tests, debug overlays).
  p.bodies[i]

proc emitBurst*(p: var Particles, pos: Vector2, count: int,
                color: Color, speed: float32, lifeSecs = 0.5'f32) =
  ## A radial puff: count particles in random directions, randomized
  ## speed and lifespan so the burst reads as debris, not a firework.
  for _ in 1..count:
    let ang = rand(2*PI)
    let spd = speed*(0.4 + rand(0.6))
    p.bodies.add(ParticleBody(
      pos: pos,
      vel: Vector2(x: float32(cos(ang))*spd, y: float32(sin(ang))*spd)))
    let life = lifeSecs*(0.5 + rand(0.5))
    p.life.add(life)
    p.maxLife.add(life)
    p.colors.add(color)

proc update*(p: var Particles, dt: float32) =
  ## Two passes. First the hot loop: move and drag, touching only the
  ## bodies array, front to back, exactly the shape CPUs love. Then
  ## bookkeeping: expire and compact, swap-and-pop across every array
  ## in lockstep, which is the tax SoA charges for its speed.
  for b in p.bodies.mitems:
    b.pos = b.pos + b.vel*dt
    b.vel = b.vel*(1 - 4*dt)         # drag; debris settles fast
  var i = 0
  while i < p.life.len:
    p.life[i] -= dt
    if p.life[i] <= 0:
      let last = p.bodies.len - 1
      p.bodies[i] = p.bodies[last]
      p.life[i] = p.life[last]
      p.maxLife[i] = p.maxLife[last]
      p.colors[i] = p.colors[last]
      p.bodies.setLen(last)
      p.life.setLen(last)
      p.maxLife.setLen(last)
      p.colors.setLen(last)
    else:
      inc i

proc draw*(p: Particles) =
  ## Small squares, fading with remaining life. Call inside the
  ## camera block; particles live in world space.
  for i in 0 ..< p.bodies.len:
    var c = p.colors[i]
    c.a = uint8(255*clamp(p.life[i]/p.maxLife[i], 0, 1))
    drawRectangle(int32(p.bodies[i].pos.x), int32(p.bodies[i].pos.y),
                  3, 3, c)

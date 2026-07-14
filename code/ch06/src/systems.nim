## Systems: procs that each run one query and do one job. The frame
## loop calls them in a fixed order; that list (in crypt_of_nimrod.nim)
## is the entire control flow of the game — no system calls another.
##
## Data flows between systems implicitly (one writes state, a later one
## reads it), which is why every system below declares what it reads
## and writes. Keep those lines accurate when editing.

import raylib, raymath
import ecs, input, resources, sprites

proc playerInputSystem*(w: var World, speed: float32) =
  ## Turns the player's held keys into velocity, overwriting whatever
  ## was there: the player moves exactly as told, every frame.
  ## Reads: the keyboard (via the action map). Writes: Velocity.
  for i in w.query({ckPlayer, ckVelocity}):
    w.velocities[i] = moveAxis()*speed

proc movementSystem*(w: var World, dt: float32) =
  ## Applies velocity to position. Entities without a Velocity are
  ## skipped by the query itself.
  ## Reads: Position, Velocity. Writes: Position.
  for i in w.query({ckPosition, ckVelocity}):
    w.positions[i] = w.positions[i] + w.velocities[i]*dt

proc bounceSystem*(w: var World, bounds: Vector2) =
  ## Keeps moving things on screen: clamps position into bounds and
  ## reflects velocity on contact. For the player the reflection is
  ## moot (input overwrites velocity next frame), so the clamp is what
  ## stops him at walls. Runs after movement, so it sees this frame's
  ## final positions.
  ## Reads: Position, Sprite. Writes: Position, Velocity.
  for i in w.query({ckPosition, ckVelocity, ckSprite}):
    let size = Vector2(x: w.sprites[i].width, y: w.sprites[i].height)
    if w.positions[i].x < 0 or w.positions[i].x + size.x > bounds.x:
      w.velocities[i].x = -w.velocities[i].x
      w.positions[i].x = clamp(w.positions[i].x, 0, bounds.x - size.x)
    if w.positions[i].y < 0 or w.positions[i].y + size.y > bounds.y:
      w.velocities[i].y = -w.velocities[i].y
      w.positions[i].y = clamp(w.positions[i].y, 0, bounds.y - size.y)

proc actorAnimSystem*(w: var World, atlas: Atlas) =
  ## Faces sprites along their horizontal motion and switches between
  ## idle and run animations. Standing still keeps the last facing.
  ## Runs after bounce, so a reflected critter faces its new direction.
  ## Reads: Velocity, Actor. Writes: Sprite.
  for i in w.query({ckVelocity, ckActor, ckSprite}):
    let v = w.velocities[i]
    if v.x < 0:
      w.sprites[i].flipX = true
    elif v.x > 0:
      w.sprites[i].flipX = false
    let anim = if length(v) > 1: w.actors[i].runAnim
               else: w.actors[i].idleAnim
    w.sprites[i].setAnim(atlas, anim)

proc animationSystem*(w: var World, dt: float32) =
  ## Advances every animation clock (Chapter 3's update behind a query).
  ## Reads: Sprite. Writes: Sprite.
  for i in w.query({ckSprite}):
    w.sprites[i].update(dt)

proc lifetimeSystem*(w: var World, dt: float32) =
  ## Counts lifetimes down; despawns what expires. Despawning edits
  ## the mask seq, so never do it while a query is running: collect
  ## the dead first, bury after.
  ## Reads: Lifetime. Writes: Lifetime, entity liveness itself.
  var dead: seq[Entity]
  for i in w.query({ckLifetime}):
    w.lifetimes[i] -= dt
    if w.lifetimes[i] <= 0:
      dead.add(w.entity(i))
  for e in dead:
    w.despawn(e)

proc drawSystem*(w: World, atlas: Atlas) =
  ## Draws every entity that has a position and a sprite, in slot
  ## order (draw-order control comes with later chapters).
  ## Reads: Position, Sprite. Writes: nothing (only the screen).
  for i in w.query({ckPosition, ckSprite}):
    w.sprites[i].draw(atlas, w.positions[i])

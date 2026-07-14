## Systems: procs that each run one query and do one job. The frame
## loop calls them in a fixed order; that list (in crypt_of_nimrod.nim)
## is the entire control flow of the game — no system calls another.
##
## Data flows between systems implicitly (one writes state, a later one
## reads it), which is why every system below declares what it reads
## and writes. Keep those lines accurate when editing.

import raylib, raymath
import collision, ecs, input, resources, sprites, tilemap

proc playerInputSystem*(w: var World, speed: float32) =
  ## Turns the player's held keys into velocity, overwriting whatever
  ## was there: the player moves exactly as told, every frame.
  ## Reads: the keyboard (via the action map). Writes: Velocity.
  for i in w.query({ckPlayer, ckVelocity}):
    w.velocities[i] = moveAxis()*speed

proc movementSystem*(w: var World, map: Tilemap, dt: float32,
                     noclip = false) =
  ## Applies velocity to position. Entities with a collider move one
  ## axis at a time and slide along solid tiles; ckBounce entities
  ## also reflect their velocity off whatever axis hit. Anything
  ## without a collider moves freely, and so does the player while
  ## debug noclip is on.
  ## Reads: Position, Velocity, Collider. Writes: Position, Velocity.
  for i in w.query({ckPosition, ckVelocity}):
    let delta = w.velocities[i]*dt
    if w.has(i, ckCollider) and not (noclip and w.has(i, ckPlayer)):
      let hit = moveAndSlide(map, w.positions[i], w.colliders[i], delta)
      if w.has(i, ckBounce):
        if hit.x: w.velocities[i].x = -w.velocities[i].x
        if hit.y: w.velocities[i].y = -w.velocities[i].y
    else:
      w.positions[i] = w.positions[i] + delta

proc contactSystem*(w: var World) =
  ## Finds every overlapping collider pair (A, B) where A cares about
  ## B (B's layer is in A's hits set). Brute force over all collider
  ## pairs: at room scale that is dozens of entities, and the whole
  ## scan is cheaper than the bookkeeping any smarter structure needs.
  ## Reads: Position, Collider. Writes: contacts (frame scratch).
  w.contacts.setLen(0)
  var idx: seq[int32]
  for i in w.query({ckPosition, ckCollider}):
    idx.add(i)
  for a in idx:
    if w.colliders[a].hits != {}:
      for b in idx:
        if a != b and w.colliders[b].layer in w.colliders[a].hits and
            checkCollisionRecs(w.colliderRect(a), w.colliderRect(b)):
          w.contacts.add((w.entity(a), w.entity(b)))

proc pickupSystem*(w: var World): int =
  ## Despawns every pickup the player touched this frame and returns
  ## how many (the caller keeps the score). Contacts are already
  ## layer-filtered; only the player has lyPickup in its hits.
  ## Reads: contacts, Collider. Writes: entity liveness itself.
  var got: seq[Entity]
  for (a, b) in w.contacts:
    if w.alive(b) and w.colliders[b.idx].layer == lyPickup:
      got.add(b)
  for e in got:
    w.despawn(e)
    inc result

proc actorAnimSystem*(w: var World, atlas: Atlas) =
  ## Faces sprites along their horizontal motion and switches between
  ## idle and run animations. Standing still keeps the last facing.
  ## Runs after movement, so a bounced critter faces its new direction.
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

## Systems: procs that each run one query and do one job. The frame
## loop calls them in a fixed order; that list (in crypt_of_nimrod.nim)
## is the entire control flow of the game — no system calls another.
##
## Data flows between systems implicitly (one writes state, a later one
## reads it), which is why every system below declares what it reads
## and writes. Keep those lines accurate when editing.

import std/random
import raylib, raymath
import collision, ecs, input, resources, sprites, tilemap

proc playerInputSystem*(w: var World, speed: float32) =
  ## Turns the player's held keys into velocity, overwriting whatever
  ## was there: the player moves exactly as told, every frame. While
  ## stunned, knockback owns the velocity and input waits.
  ## Reads: the keyboard (via the action map), Health. Writes: Velocity.
  for i in w.query({ckPlayer, ckVelocity}):
    if not (w.has(i, ckHealth) and w.healths[i].stun > 0):
      w.velocities[i] = moveAxis()*speed

proc aiSystem*(w: var World, player: Entity) =
  ## The enemy brain: wander until the player is inside aggro range,
  ## chase until they get away (with slack, so the boundary doesn't
  ## flip-flop), and do nothing while stunned.
  ## Reads: Position, Ai, Health. Writes: Velocity, Ai.
  if w.alive(player):
    let target = w.positions[player.idx]
    for i in w.query({ckAi, ckPosition, ckVelocity}):
      if not (w.has(i, ckHealth) and w.healths[i].stun > 0):
        let toPlayer = target - w.positions[i]
        let dist = length(toPlayer)
        case w.ais[i].state
        of asWander:
          if dist < w.ais[i].aggro:
            w.ais[i].state = asChase
        of asChase:
          if dist > w.ais[i].aggro*1.6:
            w.ais[i].state = asWander
            # Pick a fresh direction to drift off in.
            w.velocities[i] = Vector2(
              x: float32(rand(-60.0..60.0)),
              y: float32(rand(-60.0..60.0)))
        if w.ais[i].state == asChase and dist > 1:
          w.velocities[i] = normalize(toPlayer)*w.ais[i].chaseSpeed

proc healthSystem*(w: var World, dt: float32) =
  ## Ticks down the invulnerability and stun timers.
  ## Reads: Health. Writes: Health.
  for i in w.query({ckHealth}):
    w.healths[i].invuln -= dt
    w.healths[i].stun -= dt

proc damageSystem*(w: var World) =
  ## Applies every ContactDamage -> Health contact from this frame:
  ## subtract hp, grant i-frames, stun the victim and knock them away
  ## from whatever hit them.
  ## Reads: contacts, Collider, ContactDamage. Writes: Health, Velocity.
  for (a, b) in w.contacts:
    if w.alive(a) and w.alive(b) and
        w.has(a.idx, ckContactDamage) and w.has(b.idx, ckHealth) and
        w.healths[b.idx].invuln <= 0:
      w.healths[b.idx].hp -= w.contactDamages[a.idx].amount
      w.healths[b.idx].invuln = w.healths[b.idx].invulnTime
      w.healths[b.idx].stun = 0.2
      if w.has(b.idx, ckVelocity):
        let ar = w.colliderRect(a.idx)
        let br = w.colliderRect(b.idx)
        var dir = Vector2(
          x: br.x + br.width/2 - (ar.x + ar.width/2),
          y: br.y + br.height/2 - (ar.y + ar.height/2))
        # Dead-center overlaps have no direction; shove right.
        dir = if length(dir) > 0: normalize(dir) else: Vector2(x: 1)
        w.velocities[b.idx] = dir*w.contactDamages[a.idx].knockback

proc deathSystem*(w: var World): seq[Vector2] =
  ## Buries anything whose hp ran out, except the player (whose death
  ## is the main module's problem). Returns where each one fell so the
  ## caller can decorate the spot; systems stay GPU-free (Chapter 8's
  ## lesson, applied at design time).
  ## Reads: Health. Writes: entity liveness itself.
  var dead: seq[Entity]
  for i in w.query({ckHealth}):
    if w.healths[i].hp <= 0 and not w.has(i, ckPlayer):
      dead.add(w.entity(i))
  for e in dead:
    result.add(w.positions[e.idx])
    w.despawn(e)

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

proc pickupSystem*(w: var World): seq[PickupKind] =
  ## Despawns every pickup the player touched this frame and returns
  ## what they were; the caller decides what a coin or a key means.
  ## Reads: contacts, Collider, Pickup. Writes: entity liveness itself.
  var got: seq[Entity]
  for (a, b) in w.contacts:
    if w.alive(b) and w.colliders[b.idx].layer == lyPickup:
      got.add(b)
  for e in got:
    if w.alive(e):               # contacts can list a pickup twice
      result.add(w.pickupKinds[e.idx])
      w.despawn(e)

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

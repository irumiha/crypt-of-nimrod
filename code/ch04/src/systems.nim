import raylib, raymath
import ecs, resources, sprites

proc movementSystem*(w: var World, dt: float32) =
  for i in w.query({ckPosition, ckVelocity}):
    w.positions[i] = w.positions[i] + w.velocities[i]*dt

proc bounceSystem*(w: var World, bounds: Vector2) =
  ## Reflect anything that runs into the screen edge.
  for i in w.query({ckPosition, ckVelocity, ckSprite}):
    let size = Vector2(x: w.sprites[i].width, y: w.sprites[i].height)
    if w.positions[i].x < 0 or w.positions[i].x + size.x > bounds.x:
      w.velocities[i].x = -w.velocities[i].x
    if w.positions[i].y < 0 or w.positions[i].y + size.y > bounds.y:
      w.velocities[i].y = -w.velocities[i].y

proc animationSystem*(w: var World, dt: float32) =
  for i in w.query({ckSprite}):
    w.sprites[i].update(dt)

proc lifetimeSystem*(w: var World, dt: float32) =
  ## Count lifetimes down; despawn what expires. Never despawn while
  ## a query is running, so the dead are collected first.
  var dead: seq[Entity]
  for i in w.query({ckLifetime}):
    w.lifetimes[i] -= dt
    if w.lifetimes[i] <= 0:
      dead.add(w.entity(i))
  for e in dead:
    w.despawn(e)

proc drawSystem*(w: World, atlas: Atlas) =
  for i in w.query({ckPosition, ckSprite}):
    w.sprites[i].draw(atlas, w.positions[i])

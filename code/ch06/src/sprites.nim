## Drawing sprites out of the atlas: static ones and looping animations.
##
## Changed in Chapter 5: an AnimSprite remembers which animation it is
## playing (so setAnim can switch between idle and run without
## restarting every frame) and can draw mirrored for left-facing.

import raylib
import resources

type
  AnimSprite* = object
    ## A looping animation: which frames, how fast, where we are.
    anim: string        # base name of the animation currently playing
    frames: seq[Rectangle]
    secsPerFrame: float32
    timer: float32      # accumulates dt until one frame's worth passes
    index: int          # current frame
    scale: float32
    flipX*: bool        # draw mirrored (the sprite faces left)

proc initAnimSprite*(atlas: Atlas, name: string,
                     scale: float32 = 4, fps = 8.0): AnimSprite =
  ## An animation from the atlas by base name, e.g. "knight_m_idle_anim"
  ## collects knight_m_idle_anim_f0..f3. fps is animation speed, not
  ## render speed; the game still draws at 60.
  AnimSprite(anim: name, frames: atlas.frames(name),
             secsPerFrame: float32(1.0/fps), scale: scale)

proc setAnim*(s: var AnimSprite, atlas: Atlas, name: string) =
  ## Switches to another animation. A no-op when it is already playing,
  ## so systems can assert the desired animation every frame without
  ## resetting it to frame zero each time.
  if s.anim != name:
    s.anim = name
    s.frames = atlas.frames(name)
    s.timer = 0
    s.index = 0

proc width*(s: AnimSprite): float32 =
  ## On-screen width of the current frame, scale included.
  s.frames[s.index].width*s.scale

proc height*(s: AnimSprite): float32 =
  ## On-screen height of the current frame, scale included.
  s.frames[s.index].height*s.scale

proc update*(s: var AnimSprite, dt: float32) =
  ## Advances the animation clock. The `while` (not `if`) means a long
  ## frame hitch skips exactly the frames it should.
  s.timer += dt
  while s.timer >= s.secsPerFrame:
    s.timer -= s.secsPerFrame
    s.index = (s.index + 1) mod s.frames.len

proc draw*(s: AnimSprite, atlas: Atlas, pos: Vector2) =
  ## Draws the current frame at pos. A negative source width tells
  ## raylib to sample the region right-to-left: a free horizontal flip,
  ## no second set of art required.
  var src = s.frames[s.index]
  if s.flipX:
    src.width = -src.width
  let dest = Rectangle(x: pos.x, y: pos.y,
                       width: s.frames[s.index].width*s.scale,
                       height: s.frames[s.index].height*s.scale)
  drawTexture(atlas.texture, src, dest, Vector2(x: 0, y: 0), 0, White)

proc draw*(atlas: Atlas, name: string, pos: Vector2, scale: float32) =
  ## A single static sprite by name, scaled.
  let src = atlas.rect(name)
  let dest = Rectangle(x: pos.x, y: pos.y,
                       width: src.width*scale, height: src.height*scale)
  drawTexture(atlas.texture, src, dest, Vector2(x: 0, y: 0), 0, White)

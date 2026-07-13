## Drawing sprites out of the atlas: static ones and looping animations.
##
## Changed in Chapter 4: the scale factor lives inside AnimSprite (a
## sprite's on-screen size is the sprite's business), with width/height
## accessors so systems like bounce can ask.

import raylib
import resources

type
  AnimSprite* = object
    ## A looping animation: which frames, how fast, where we are.
    frames: seq[Rectangle]
    secsPerFrame: float32
    timer: float32      # accumulates dt until one frame's worth passes
    index: int          # current frame
    scale: float32

proc initAnimSprite*(atlas: Atlas, name: string,
                     scale: float32 = 4, fps = 8.0): AnimSprite =
  ## An animation from the atlas by base name, e.g. "knight_m_idle_anim"
  ## collects knight_m_idle_anim_f0..f3. fps is animation speed, not
  ## render speed; the game still draws at 60.
  AnimSprite(frames: atlas.frames(name),
             secsPerFrame: float32(1.0/fps), scale: scale)

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
  ## Draws the current frame at pos. Copies the frame's source
  ## rectangle from the atlas texture onto a destination rectangle on
  ## screen (raylib's DrawTexturePro).
  let src = s.frames[s.index]
  let dest = Rectangle(x: pos.x, y: pos.y,
                       width: src.width*s.scale, height: src.height*s.scale)
  drawTexture(atlas.texture, src, dest, Vector2(x: 0, y: 0), 0, White)

proc draw*(atlas: Atlas, name: string, pos: Vector2, scale: float32) =
  ## A single static sprite by name, scaled.
  let src = atlas.rect(name)
  let dest = Rectangle(x: pos.x, y: pos.y,
                       width: src.width*scale, height: src.height*scale)
  drawTexture(atlas.texture, src, dest, Vector2(x: 0, y: 0), 0, White)

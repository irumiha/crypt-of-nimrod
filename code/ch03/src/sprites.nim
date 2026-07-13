## Drawing sprites out of the atlas: static ones and looping animations.

import raylib
import resources

type
  AnimSprite* = object
    ## A looping animation: which frames, how fast, where we are.
    frames: seq[Rectangle]
    secsPerFrame: float32
    timer: float32      # accumulates dt until one frame's worth passes
    index: int          # current frame

proc initAnimSprite*(atlas: Atlas, name: string, fps = 8.0): AnimSprite =
  ## An animation from the atlas by base name, e.g. "knight_m_idle_anim"
  ## collects knight_m_idle_anim_f0..f3. fps is animation speed, not
  ## render speed; the game still draws at 60.
  AnimSprite(frames: atlas.frames(name), secsPerFrame: float32(1.0/fps))

proc update*(s: var AnimSprite, dt: float32) =
  ## Advances the animation clock. The `while` (not `if`) means a long
  ## frame hitch skips exactly the frames it should.
  s.timer += dt
  while s.timer >= s.secsPerFrame:
    s.timer -= s.secsPerFrame
    s.index = (s.index + 1) mod s.frames.len

proc draw*(s: AnimSprite, atlas: Atlas, pos: Vector2, scale: float32) =
  ## Draws the current frame at pos, scaled. Copies the frame's source
  ## rectangle from the atlas texture onto a destination rectangle on
  ## screen (raylib's DrawTexturePro).
  let src = s.frames[s.index]
  let dest = Rectangle(x: pos.x, y: pos.y,
                       width: src.width*scale, height: src.height*scale)
  drawTexture(atlas.texture, src, dest, Vector2(x: 0, y: 0), 0, White)

proc draw*(atlas: Atlas, name: string, pos: Vector2, scale: float32) =
  ## A single static sprite by name, scaled.
  let src = atlas.rect(name)
  let dest = Rectangle(x: pos.x, y: pos.y,
                       width: src.width*scale, height: src.height*scale)
  drawTexture(atlas.texture, src, dest, Vector2(x: 0, y: 0), 0, White)

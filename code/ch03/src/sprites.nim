import raylib
import resources

type
  AnimSprite* = object
    frames: seq[Rectangle]
    secsPerFrame: float32
    timer: float32
    index: int

proc initAnimSprite*(atlas: Atlas, name: string, fps = 8.0): AnimSprite =
  AnimSprite(frames: atlas.frames(name), secsPerFrame: float32(1.0/fps))

proc update*(s: var AnimSprite, dt: float32) =
  s.timer += dt
  while s.timer >= s.secsPerFrame:
    s.timer -= s.secsPerFrame
    s.index = (s.index + 1) mod s.frames.len

proc draw*(s: AnimSprite, atlas: Atlas, pos: Vector2, scale: float32) =
  let src = s.frames[s.index]
  let dest = Rectangle(x: pos.x, y: pos.y,
                       width: src.width*scale, height: src.height*scale)
  drawTexture(atlas.texture, src, dest, Vector2(x: 0, y: 0), 0, White)

proc draw*(atlas: Atlas, name: string, pos: Vector2, scale: float32) =
  ## A single static sprite, scaled.
  let src = atlas.rect(name)
  let dest = Rectangle(x: pos.x, y: pos.y,
                       width: src.width*scale, height: src.height*scale)
  drawTexture(atlas.texture, src, dest, Vector2(x: 0, y: 0), 0, White)

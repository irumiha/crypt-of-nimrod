import raylib
import resources

type
  AnimSprite* = object
    frames: seq[Rectangle]
    secsPerFrame: float32
    timer: float32
    index: int
    scale: float32

proc initAnimSprite*(atlas: Atlas, name: string,
                     scale: float32 = 4, fps = 8.0): AnimSprite =
  AnimSprite(frames: atlas.frames(name),
             secsPerFrame: float32(1.0/fps), scale: scale)

proc width*(s: AnimSprite): float32 =
  s.frames[s.index].width*s.scale

proc height*(s: AnimSprite): float32 =
  s.frames[s.index].height*s.scale

proc update*(s: var AnimSprite, dt: float32) =
  s.timer += dt
  while s.timer >= s.secsPerFrame:
    s.timer -= s.secsPerFrame
    s.index = (s.index + 1) mod s.frames.len

proc draw*(s: AnimSprite, atlas: Atlas, pos: Vector2) =
  let src = s.frames[s.index]
  let dest = Rectangle(x: pos.x, y: pos.y,
                       width: src.width*s.scale, height: src.height*s.scale)
  drawTexture(atlas.texture, src, dest, Vector2(x: 0, y: 0), 0, White)

proc draw*(atlas: Atlas, name: string, pos: Vector2, scale: float32) =
  ## A single static sprite, scaled.
  let src = atlas.rect(name)
  let dest = Rectangle(x: pos.x, y: pos.y,
                       width: src.width*scale, height: src.height*scale)
  drawTexture(atlas.texture, src, dest, Vector2(x: 0, y: 0), 0, White)

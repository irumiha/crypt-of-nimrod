## The camera: a moving window over a world bigger than the screen.
##
## raylib's Camera2D does the actual work (everything drawn between
## beginMode2D and endMode2D is shifted by it); this module only
## decides where it should look.

import raylib, raymath

proc makeCamera*(screenSize: Vector2): Camera2D =
  ## A camera whose `offset` pins the watched point (`target`) to the
  ## middle of the screen.
  Camera2D(offset: screenSize*0.5, target: Vector2(), zoom: 1)

proc adaptToDpi*(cam: var Camera2D, screenSize: Vector2) =
  ## raylib scales screen-space drawing on HiDPI displays, but resets
  ## the matrix inside beginMode2D, so world rendering must bake the
  ## DPI scale into the camera itself: zoom by the scale, and pin the
  ## target to the center of the real framebuffer. A no-op at scale 1,
  ## and follow()'s clamps stay correct because they divide by zoom.
  let s = getWindowScaleDPI().x
  cam.zoom = s
  cam.offset = screenSize*(0.5*s)

proc follow*(cam: var Camera2D, target: Vector2, mapSize: Vector2,
             dt: float32) =
  ## Eases the camera toward the target, then clamps it so the view
  ## never shows past the map's edges. The easing factor is scaled by
  ## dt, so the glide feels the same at any frame rate.
  let ease = min(1.0'f32, 10*dt)
  cam.target = cam.target + (target - cam.target)*ease
  # Half a screen of margin on each side keeps the view inside the map.
  let halfView = cam.offset/cam.zoom
  cam.target.x = clamp(cam.target.x, halfView.x, mapSize.x - halfView.x)
  cam.target.y = clamp(cam.target.y, halfView.y, mapSize.y - halfView.y)

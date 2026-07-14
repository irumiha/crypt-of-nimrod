## The camera: a moving window over a world bigger than the screen.
##
## raylib's Camera2D does the actual work (everything drawn between
## beginMode2D and endMode2D is shifted by it); this module only
## decides where it should look.

import std/[math, random]
import raylib, raymath

# Three rlgl symbols, imported directly: the rlgl Nim module can't be
# imported alongside raylib (duplicate C Matrix definition), and three
# declarations are cheaper than a workaround module.
proc rlLoadFramebuffer(): uint32 {.importc, cdecl.}
proc rlFramebufferAttach(fbo, tex: uint32,
                         attachType, texType, mip: int32) {.importc, cdecl.}
proc rlFramebufferComplete(fbo: uint32): bool {.importc, cdecl.}

proc loadCanvas*(width, height: int32): RenderTexture2D =
  ## LoadRenderTexture, reassembled by hand. The raylib bundled with
  ## naylib 26.08 creates its render-texture color buffer through
  ## rlLoadTexture(nil, ...), which this driver rejects (GL_INVALID_ENUM
  ## at creation, incomplete framebuffer forever after). The texture
  ## path every sprite already uses works fine, so: make the color
  ## texture from a blank Image, then assemble the framebuffer around
  ## it. No depth attachment; 2D rendering never reads one.
  let img = genImageColor(width, height, Blank)
  var tex = loadTextureFromImage(img)
  let fb = rlLoadFramebuffer()
  rlFramebufferAttach(fb, tex.id, 0, 100, 0)   # color0 <- texture2d
  doAssert rlFramebufferComplete(fb), "render target incomplete"
  RenderTexture2D(id: fb, texture: tex, depth: Texture())


proc makeCamera*(screenSize: Vector2): Camera2D =
  ## A camera whose `offset` pins the watched point (`target`) to the
  ## middle of the screen.
  Camera2D(offset: screenSize*0.5, target: Vector2(), zoom: 1)

type
  Viewport* = object
    ## Where the fixed logical frame lands inside the real window:
    ## integer-scaled, centered, letterboxed. The world never learns
    ## the window's size; presentation is the only thing that scales.
    dest*: Rectangle
    logicalW*, logicalH*: int32

proc computeViewport*(logicalW, logicalH: int32): Viewport =
  ## The biggest integer scale that fits the physical framebuffer,
  ## converted back to raylib's screen units for the final blit (on a
  ## HiDPI display those units are scaled by the OS factor, so doing
  ## the integer math in physical pixels keeps texels square).
  when defined(emscripten):
    # On the web the canvas IS the framebuffer: screen units and
    # physical pixels are the same 800x450, and the page does the
    # display scaling (see web/shell.html). raylib still reports the
    # browser's devicePixelRatio here, and dividing by it would blit
    # the game into a dpr-sized corner of its own canvas — which is
    # exactly what it did, on the first HiDPI screen it met.
    let dpi = 1'f32
  else:
    let dpi = getWindowScaleDPI().x
  let physW = float32(getRenderWidth())
  let physH = float32(getRenderHeight())
  let s = max(1'f32, floor(min(physW/float32(logicalW),
                               physH/float32(logicalH))))
  let w = s*float32(logicalW)/dpi
  let h = s*float32(logicalH)/dpi
  Viewport(
    dest: Rectangle(x: (float32(getScreenWidth()) - w)/2,
                    y: (float32(getScreenHeight()) - h)/2,
                    width: w, height: h),
    logicalW: logicalW, logicalH: logicalH)

proc mouseLogical*(vp: Viewport): Vector2 =
  ## The mouse position in logical-frame coordinates, compensating
  ## for the letterbox offset and the blit scale.
  let m = getMousePosition()
  Vector2(
    x: (m.x - vp.dest.x)*float32(vp.logicalW)/vp.dest.width,
    y: (m.y - vp.dest.y)*float32(vp.logicalH)/vp.dest.height)

type
  Shake* = object
    ## Trauma-based screen shake (Squirrel Eiserloh's GDC recipe):
    ## hits add trauma, trauma decays linearly, and displacement is
    ## proportional to trauma SQUARED, so small knocks murmur and big
    ## ones throw the room. A linear response feels like a metronome.
    trauma*: float32

proc addTrauma*(s: var Shake, amount: float32) =
  s.trauma = min(1.0'f32, s.trauma + amount)

proc update*(s: var Shake, dt: float32) =
  s.trauma = max(0.0'f32, s.trauma - 1.5*dt)

proc offset*(s: Shake): Vector2 =
  ## This frame's shake displacement, in logical pixels (6 max).
  let m = s.trauma*s.trauma*6
  Vector2(x: float32(rand(-1.0..1.0))*m,
          y: float32(rand(-1.0..1.0))*m)

proc follow*(cam: var Camera2D, target: Vector2, mapSize: Vector2,
             dt: float32, speed: float32 = 10) =
  ## Eases the camera toward the target, then clamps it so the view
  ## never shows past the map's edges. The easing factor is scaled by
  ## dt, so the glide feels the same at any frame rate; lower speed
  ## gives a slower pan (room transitions use 6).
  let ease = min(1.0'f32, speed*dt)
  cam.target = cam.target + (target - cam.target)*ease
  # Half a screen of margin on each side keeps the view inside the map.
  let halfView = cam.offset/cam.zoom
  cam.target.x = clamp(cam.target.x, halfView.x, mapSize.x - halfView.x)
  cam.target.y = clamp(cam.target.y, halfView.y, mapSize.y - halfView.y)

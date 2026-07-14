## Loading and feeding the game's two fragment shaders (Chapter 15).
##
## The GLSL sources live in shaders/ (next to src/, not under assets/:
## they are code we maintain, not art we licensed) in two dialects:
## *-330.fs for desktop OpenGL, *-100.fs twins for the web build.
## Which dialect loads is decided at compile time; nothing else in the
## game knows there are two.

import raylib
import resources

const glslSuffix =
  when defined(emscripten): "-100.fs"
  else: "-330.fs"

type
  Fx* = object
    ## The shaders plus the one uniform location that changes at draw
    ## time. Locations are looked up once at load; asking by name every
    ## frame works too, but a location is an int and the name lookup
    ## is a string search.
    outline*: Shader
    crt*: Shader
    regionLoc: ShaderLocation

proc loadFx*(atlas: Atlas, canvasW, canvasH: int32): Fx =
  ## Loads both shaders and sets every uniform that never changes:
  ## the atlas texel size, the outline color, the canvas resolution.
  ## The empty string means "keep raylib's default vertex shader";
  ## these effects only bend fragments.
  result.outline = loadShader("", "shaders/outline" & glslSuffix)
  result.regionLoc = getShaderLocation(result.outline, "region")
  setShaderValue(result.outline,
    getShaderLocation(result.outline, "texelSize"),
    Vector2(x: 1/float32(atlas.texture.width),
            y: 1/float32(atlas.texture.height)))
  setShaderValue(result.outline,
    getShaderLocation(result.outline, "outlineColor"),
    Vector4(x: 1, y: 0.84, z: 0.2, w: 1))          # gold, like the HUD
  result.crt = loadShader("", "shaders/crt" & glslSuffix)
  setShaderValue(result.crt,
    getShaderLocation(result.crt, "resolution"),
    Vector2(x: float32(canvasW), y: float32(canvasH)))

proc setOutlineRegion*(fx: Fx, atlas: Atlas, src: Rectangle) =
  ## Points the outline shader at one sprite's atlas cell, inset half
  ## a texel so the clamped neighbor samples can't bleed color from
  ## the sprite next door.
  let tw = float32(atlas.texture.width)
  let th = float32(atlas.texture.height)
  setShaderValue(fx.outline, fx.regionLoc, Vector4(
    x: (src.x + 0.5)/tw, y: (src.y + 0.5)/th,
    z: (src.x + src.width - 0.5)/tw,
    w: (src.y + src.height - 0.5)/th))

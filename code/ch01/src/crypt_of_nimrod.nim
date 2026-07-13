## Chapter 1: a window, a game loop, and a bobbing crown.
##
## This is the whole "engine": open a window, then loop forever doing
## update-a-little, draw-everything. Every later chapter keeps exactly
## this shape and only grows the two halves of the loop.

import std/math
import raylib

const
  screenWidth = 1600
  screenHeight = 900
  # The palette of the crypt: near-black purple and old gold.
  backgroundColor = Color(r: 24, g: 20, b: 37, a: 255)
  crownColor = Color(r: 232, g: 193, b: 112, a: 255)

proc drawCrown(cx, cy: int32) =
  ## Draws a crown of plain shapes centered-ish on (cx, cy), in screen
  ## coordinates (origin top-left, y grows downward). Programmer art;
  ## the real crown is at the bottom of the crypt.
  let left = cx - 120
  let top = cy - 80
  # The band.
  drawRectangle(left, top + 100, 240, 60, crownColor)
  # Three prongs, rendered as triangles. Vertices must be given in
  # counter-clockwise order or raylib culls the triangle entirely.
  for i in 0'i32..2'i32:
    let px = left + i*80
    drawTriangle(
      Vector2(x: float32(px), y: float32(top + 100)),
      Vector2(x: float32(px + 80), y: float32(top + 100)),
      Vector2(x: float32(px + 40), y: float32(top)),
      crownColor)
  # The jewel, set in the middle of the band.
  drawCircle(cx, cy + 50, 18, Color(r: 165, g: 48, b: 48, a: 255))

proc main =
  # HighDPI must be requested before the window exists. Without it, a
  # display at 200% scaling shows the window at half the intended size.
  setConfigFlags(flags(WindowHighdpi))
  initWindow(screenWidth, screenHeight, "Crypt of Nimrod")
  defer: closeWindow()          # runs when main exits, however it exits
  setTargetFPS(60)

  var elapsed: float32 = 0

  while not windowShouldClose():
    # --- Update ---
    # dt is the previous frame's duration in seconds. Anything that
    # moves gets multiplied by it, so speed is per-second, not per-frame.
    let dt = getFrameTime()
    elapsed += dt
    # A gentle bob: 20 pixels of amplitude, one full cycle per two seconds.
    let bob = int32(20*sin(elapsed*PI))

    # --- Draw ---
    # Immediate mode: nothing persists between frames. Clear, then
    # redraw the entire scene, every frame.
    beginDrawing()
    clearBackground(backgroundColor)
    drawCrown(screenWidth div 2, screenHeight div 2 - 80 + bob)
    let title = "CRYPT OF NIMROD"
    let titleWidth = measureText(title, 80)
    drawText(title, (screenWidth - titleWidth) div 2, 600, 80, crownColor)
    let subtitle = "a roguelite, eventually"
    let subWidth = measureText(subtitle, 40)
    drawText(subtitle, (screenWidth - subWidth) div 2, 700, 40, LightGray)
    drawFPS(10, 10)
    endDrawing()

main()

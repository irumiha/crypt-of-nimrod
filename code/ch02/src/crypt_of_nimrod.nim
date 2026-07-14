## Chapter 2: the Chapter 1 title scene, plus a field of embers.
##
## The embers live in `embers.nim`; this file owns their storage (a
## plain seq) and decides when to spawn one. See also `tour.nim` for
## this chapter's language tour, runnable via `nimble tour`.

import std/[math, random]
import raylib
import embers

const
  screenWidth = 800
  screenHeight = 450
  # The palette of the crypt: near-black purple and old gold.
  backgroundColor = Color(r: 24, g: 20, b: 37, a: 255)
  crownColor = Color(r: 232, g: 193, b: 112, a: 255)

proc drawCrown(cx, cy: int32) =
  ## Draws a crown of plain shapes centered-ish on (cx, cy).
  ## Programmer art; the real crown is at the bottom of the crypt.
  let left = cx - 60
  let top = cy - 40
  # The band.
  drawRectangle(left, top + 50, 120, 30, crownColor)
  # Three prongs, rendered as triangles (counter-clockwise winding,
  # or raylib culls them).
  for i in 0'i32..2'i32:
    let px = left + i*40
    drawTriangle(
      Vector2(x: float32(px), y: float32(top + 50)),
      Vector2(x: float32(px + 40), y: float32(top + 50)),
      Vector2(x: float32(px + 20), y: float32(top)),
      crownColor)
  # The jewel, set in the middle of the band.
  drawCircle(cx, cy + 25, 9, Color(r: 165, g: 48, b: 48, a: 255))

proc main =
  randomize()                   # seed std/random; remove for replayable "randomness"
  setConfigFlags(flags(WindowHighdpi))
  initWindow(screenWidth, screenHeight, "Crypt of Nimrod")
  defer: closeWindow()
  setTargetFPS(60)

  var elapsed: float32 = 0
  var emberField: seq[Ember] = @[]
  var spawnTimer: float32 = 0

  while not windowShouldClose():
    # --- Update ---
    let dt = getFrameTime()
    elapsed += dt
    # A gentle bob: 10 pixels of amplitude, one full cycle per two seconds.
    let bob = int32(10*sin(elapsed*PI))
    # A countdown timer: refill on expiry, spawn one ember. The same
    # shape later paces weapon cooldowns.
    spawnTimer -= dt
    if spawnTimer <= 0:
      spawnTimer = 0.03
      emberField.add(spawnEmber(screenWidth/2, screenHeight/2 + 65))
    emberField.update(dt)

    # --- Draw ---
    beginDrawing()
    clearBackground(backgroundColor)
    emberField.draw()           # before the crown: embers rise behind it
    drawCrown(screenWidth div 2, screenHeight div 2 - 40 + bob)
    let title = "CRYPT OF NIMROD"
    let titleWidth = measureText(title, 40)
    drawText(title, (screenWidth - titleWidth) div 2, 300, 40, crownColor)
    let subtitle = "a roguelite, eventually"
    let subWidth = measureText(subtitle, 20)
    drawText(subtitle, (screenWidth - subWidth) div 2, 350, 20, LightGray)
    drawFPS(10, 10)
    endDrawing()

main()

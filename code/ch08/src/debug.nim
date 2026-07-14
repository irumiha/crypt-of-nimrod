## The debug instrument panel: god powers for the person testing.
##
## F1 toggles it. While it's on: N toggles noclip, F2 cycles the time
## scale, and the main module wires T (teleport to cursor) and E
## (spawn a critter at cursor) because those need its spawn context.
## Debug tooling reads raw keys on purpose; the action map is for
## gameplay, and nobody rebinds their debugger.

import std/strformat
import raylib
import ecs

type
  Debug* = object
    enabled*: bool
    noclip*: bool      # the player ignores walls while true
    timeScale*: float32

const timeScales = [0.2'f32, 1, 3]

proc initDebug*(): Debug =
  Debug(timeScale: 1)

proc update*(d: var Debug) =
  ## Handles the debug-mode toggles. Runs every frame, cheap when off.
  if isKeyPressed(F1):
    d.enabled = not d.enabled
  if d.enabled:
    if isKeyPressed(N):
      d.noclip = not d.noclip
    if isKeyPressed(F2):
      let at = timeScales.find(d.timeScale)
      d.timeScale = timeScales[(at + 1) mod timeScales.len]

proc mouseWorld*(cam: Camera2D): Vector2 =
  ## The mouse position in world coordinates: the camera transform,
  ## inverted. raylib does the matrix math.
  getScreenToWorld2D(getMousePosition(), cam)

proc drawWorld*(d: Debug, w: World) =
  ## World-space overlay (call between beginMode2D and endMode2D):
  ## every collider box, outlined. Seeing hitboxes ends arguments.
  if d.enabled:
    for i in w.query({ckPosition, ckCollider}):
      drawRectangleLines(w.colliderRect(i), 2, Red)

proc drawPanel*(d: Debug, w: World, cam: Camera2D) =
  ## Screen-space overlay: the status line, plus a full dump of any
  ## entity the mouse hovers (the echo test, aimed with the cursor).
  if d.enabled:
    let status = &"DEBUG  [N]oclip:{d.noclip}  [F2]time:x{d.timeScale}  " &
                 "[T]eleport [E]spawn"
    drawText(status, 10, 100, 20, Red)
    let mw = mouseWorld(cam)
    for i in w.query({ckPosition, ckCollider}):
      if checkCollisionPointRec(mw, w.colliderRect(i)):
        drawText(w.dump(w.entity(i)), 10, 130, 20, Yellow)
        break

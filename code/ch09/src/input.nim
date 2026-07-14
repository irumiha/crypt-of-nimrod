## The action map: gameplay code asks about intentions ("is the player
## moving left?"), never about keys. Bindings live in one table, so
## WASD and arrows both work today, rebinding is a data change, and a
## gamepad can join later without touching any system.

import raylib, raymath

type
  Action* = enum
    aMoveLeft, aMoveRight, aMoveUp, aMoveDown, aAttack

const bindings: array[Action, seq[KeyboardKey]] = [
  aMoveLeft:  @[KeyboardKey.A, KeyboardKey.Left],
  aMoveRight: @[KeyboardKey.D, KeyboardKey.Right],
  aMoveUp:    @[KeyboardKey.W, KeyboardKey.Up],
  aMoveDown:  @[KeyboardKey.S, KeyboardKey.Down],
  aAttack:    @[KeyboardKey.Space, KeyboardKey.J]]

proc isDown*(a: Action): bool =
  ## True while any key bound to the action is held.
  for key in bindings[a]:
    if isKeyDown(key):
      return true

proc wasPressed*(a: Action): bool =
  ## True on the frame any key bound to the action went down.
  for key in bindings[a]:
    if isKeyPressed(key):
      return true

proc moveAxis*(): Vector2 =
  ## The player's movement intention as a unit vector (or zero).
  ## Normalized so holding two keys doesn't move 41% faster diagonally.
  if isDown(aMoveLeft): result.x -= 1
  if isDown(aMoveRight): result.x += 1
  if isDown(aMoveUp): result.y -= 1
  if isDown(aMoveDown): result.y += 1
  if length(result) > 0:
    result = normalize(result)

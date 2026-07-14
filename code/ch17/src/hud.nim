## The HUD: everything drawn on the glass rather than in the world
## (hearts, the purse, the minimap), plus one world-space guest, the
## floating damage numbers. Screen-space procs are called after
## endMode2D; drawFloatingTexts is called inside the camera block.

import std/strformat
import raylib
import dungeon, ecs, resources

proc drawIconStat(atlas: Atlas, icon: string, x, y: int32,
                  value: string, color: Color) =
  ## A small atlas icon (scaled to 24 px tall, aspect kept) with a
  ## number next to it. The whole HUD is variations of this.
  let src = atlas.rect(icon)
  let h = 24'f32
  let w = src.width*h/src.height
  drawTexture(atlas.texture, src,
              Rectangle(x: float32(x), y: float32(y), width: w, height: h),
              Vector2(x: 0, y: 0), 0, White)
  drawText(value, x + int32(w) + 6, y + 2, 20, color)

proc drawHearts(atlas: Atlas, hp, maxHp: int32) =
  ## One heart per max hit point, full or empty. Icons over numerals:
  ## you can read hearts from the corner of an eye mid-dodge.
  let full = atlas.rect("ui_heart_full")
  let empty = atlas.rect("ui_heart_empty")
  for i in 0'i32 ..< maxHp:
    let src = if i < hp: full else: empty
    drawTexture(atlas.texture, src,
                Rectangle(x: float32(10 + i*30), y: 34,
                          width: 26, height: 24),
                Vector2(x: 0, y: 0), 0, White)

proc drawMinimap(d: Dungeon, current: int, screenW: int32) =
  ## The floor graph as it is: one small rectangle per room, in grid
  ## positions, top-right. Gold is the sealed stairs room (green once
  ## open); the outlined cell is where you are.
  const cw = 22'i32
  const ch = 13'i32
  const pad = 3'i32
  let ox = screenW - roomCols*(cw + pad) - 10
  let oy = 10'i32
  for i, r in d.rooms:
    let x = ox + r.gx*(cw + pad)
    let y = oy + r.gy*(ch + pad)
    let color = if i == d.stairsRoom and d.isLocked: Gold
                elif i == d.stairsRoom: Green
                else: Color(r: 90, g: 85, b: 110, a: 255)
    drawRectangle(x, y, cw, ch, color)
    if i == current:
      drawRectangleLines(Rectangle(x: float32(x), y: float32(y),
                                   width: float32(cw), height: float32(ch)),
                         2, RayWhite)

proc drawHud*(atlas: Atlas, d: Dungeon, current: int, hp: Health,
              coins: int, power: int32, floorNum: int,
              screenW: int32) =
  ## The whole screen-space layer, one call in the main loop.
  drawHearts(atlas, hp.hp, hp.maxHp)
  drawIconStat(atlas, "coin_anim_f0", 10, 66, $coins, Gold)
  drawIconStat(atlas, "weapon_knight_sword", 90, 66, $power, Green)
  drawIconStat(atlas, "floor_stairs", 10, 96, &"floor {floorNum}",
               LightGray)
  drawIconStat(atlas, "flask_big_yellow", 130, 96,
               if d.isLocked: "sealed" else: "open",
               if d.isLocked: Gold else: Green)
  drawMinimap(d, current, screenW)

proc drawBossBar*(name: string, hp, maxHp: int32,
                  screenW, screenH: int32) =
  ## The classic bottom-of-screen boss health bar: it appears when the
  ## fight starts and its length is the fight's progress. Screen
  ## space; call it after endMode2D, when the boss is alive and the
  ## player is in its room.
  const w = 300'i32
  const h = 10'i32
  let x = (screenW - w) div 2
  let y = screenH - 34
  drawText(name, (screenW - measureText(name, 16)) div 2, y - 20, 16,
           Color(r: 220, g: 60, b: 60, a: 255))
  drawRectangle(x - 2, y - 2, w + 4, h + 4, Color(r: 0, g: 0, b: 0, a: 180))
  drawRectangle(x, y, int32(w*hp div max(1, maxHp)), h,
                Color(r: 200, g: 40, b: 40, a: 255))

proc drawFloatingTexts*(w: World) =
  ## World-space damage numbers: call inside beginMode2D. They fade
  ## out over their lifetime and drift on their own velocity.
  for i in w.query({ckPosition, ckFloatText, ckLifetime}):
    let alpha = uint8(255*clamp(w.lifetimes[i]/0.7, 0, 1))
    drawText(w.floatTexts[i], int32(w.positions[i].x),
             int32(w.positions[i].y), 16,
             Color(r: 255, g: 240, b: 200, a: alpha))

## Chapter 16: the boss and the run. Three floors down, the Warden
## keeps the crown: the seals slam shut behind you, the fight has a
## health bar and a phase flip, and winning is a fifth game phase the
## compiler refused to let us forget. Everything the boss does is
## assembled from parts the previous fifteen chapters already built.

import std/[math, options, random]
import raylib, raymath
import audio, bestiary, camera, debug, dungeon, ecs, hud, input, loot,
       particles, resources, shaders, sprites, systems, tilemap

const
  screenWidth = 800
  screenHeight = 450
  playerSpeed = 170
  floorCount = 3         # the run: two floors of dungeon, then the throne
  attackCooldownTime = 0.35
  backgroundColor = Color(r: 24, g: 20, b: 37, a: 255)
  crownColor = Color(r: 232, g: 193, b: 112, a: 255)
  atlasDir = "assets/0x72_DungeonTilesetII_v1.7/"

type
  GamePhase = enum
    gpMenu, gpPlaying, gpPaused, gpGameOver, gpVictory

  Run = object
    ## Everything one playthrough owns. Starting over is constructing
    ## a new Run; there is no reset or cleanup code anywhere.
    world: World
    crypt: Dungeon
    knight: Entity
    floorNum: int
    coins, kills: int
    swordPower: int32
    attackCooldown: float32
    seed: int64
    dropRng: Rand

proc spawnEnemy(w: var World, atlas: Atlas, pos: Vector2,
                stats: EnemyStats): Entity {.discardable.} =
  ## One archetype from the bestiary, assembled as a component bundle.
  ## The caller picks and scales the stats; this proc just builds.
  let e = w.spawn({ckPosition, ckVelocity, ckSprite, ckActor,
                   ckCollider, ckBounce, ckHealth, ckAi,
                   ckContactDamage})
  w.sprites[e.idx] = initAnimSprite(atlas, stats.name & "_idle_anim", scale)
  w.actors[e.idx] = Actor(idleAnim: stats.name & "_idle_anim",
                          runAnim: stats.name & "_run_anim")
  w.colliders[e.idx] = feetCollider(w.sprites[e.idx], lyEnemy,
                                    hits = {lyPlayer})
  w.healths[e.idx] = Health(hp: stats.hp, maxHp: stats.hp,
                            invulnTime: 0.3)
  w.ais[e.idx] = Ai(chaseSpeed: stats.speed, aggro: stats.aggro)
  w.contactDamages[e.idx] = ContactDamage(amount: 1, knockback: 250)
  w.positions[e.idx] = pos
  w.velocities[e.idx] = Vector2(
    x: float32(rand(-60.0..60.0)),
    y: float32(rand(-60.0..60.0)))
  e

proc spawnBoss(w: var World, atlas: Atlas,
               pos: Vector2): Entity {.discardable.} =
  ## The Warden: the ordinary enemy bundle plus ckBoss and bigger
  ## everything. It reuses Ai wholesale (chasing is chasing); the boss
  ## system only layers phases on top.
  let e = w.spawn({ckPosition, ckVelocity, ckSprite, ckActor,
                   ckCollider, ckHealth, ckAi, ckContactDamage, ckBoss})
  w.sprites[e.idx] = initAnimSprite(atlas, warden.name & "_idle_anim", scale)
  w.actors[e.idx] = Actor(idleAnim: warden.name & "_idle_anim",
                          runAnim: warden.name & "_run_anim")
  w.colliders[e.idx] = feetCollider(w.sprites[e.idx], lyEnemy,
                                    hits = {lyPlayer})
  w.healths[e.idx] = Health(hp: warden.hp, maxHp: warden.hp,
                            invulnTime: 0.15)
  w.ais[e.idx] = Ai(chaseSpeed: warden.speed, aggro: warden.aggro)
  w.contactDamages[e.idx] = ContactDamage(amount: 1, knockback: 350)
  w.positions[e.idx] = pos
  e

proc spawnCrown(w: var World, pos: Vector2) =
  ## The win condition, as an entity: position, collider, pickup, and
  ## no sprite at all. The art pack has no crown, and it shouldn't:
  ## this one has been ours since Chapter 1, and the draw pass renders
  ## it with the same primitives the title screen uses.
  let e = w.spawn({ckPosition, ckCollider, ckPickup})
  w.positions[e.idx] = pos
  w.colliders[e.idx] = Collider(size: Vector2(x: 38, y: 26),
                                layer: lyPickup)
  w.pickupKinds[e.idx] = pkCrown

proc spawnLoot(w: var World, atlas: Atlas, pos: Vector2,
               kind: PickupKind) =
  ## One dropped item where an enemy fell. Drops expire after a while;
  ## the crypt keeps a tidy floor.
  let e = w.spawn({ckPosition, ckSprite, ckLifetime, ckCollider,
                   ckPickup})
  w.sprites[e.idx] = case kind
    of pkCoin: initAnimSprite(atlas, "coin_anim", scale)
    of pkHeart: initStaticSprite(atlas, "ui_heart_full", scale)
    of pkMaxHp: initStaticSprite(atlas, "flask_big_blue", scale)
    of pkPower: initStaticSprite(atlas, "flask_big_green", scale)
    of pkKey: initStaticSprite(atlas, "flask_big_yellow", scale)
    of pkCrown: raiseAssert("the crown spawns via spawnCrown")
  w.colliders[e.idx] = Collider(
    size: Vector2(x: w.sprites[e.idx].width, y: w.sprites[e.idx].height),
    layer: lyPickup)
  w.pickupKinds[e.idx] = kind
  w.positions[e.idx] = pos
  w.lifetimes[e.idx] = 12

proc spawnKey(w: var World, atlas: Atlas, pos: Vector2) =
  ## The seal-dissolving flask. Persistent: no lifetime, it waits.
  let e = w.spawn({ckPosition, ckSprite, ckCollider, ckPickup})
  w.sprites[e.idx] = initStaticSprite(atlas, "flask_big_yellow", scale)
  w.colliders[e.idx] = Collider(
    size: Vector2(x: w.sprites[e.idx].width, y: w.sprites[e.idx].height),
    layer: lyPickup)
  w.pickupKinds[e.idx] = pkKey
  w.positions[e.idx] = pos

proc swingSword(w: var World, atlas: Atlas, player: Entity,
                damage: int32) =
  ## The sword: an entity with a sprite, a hitbox slightly bigger than
  ## the blade, one point of damage, and 0.15 seconds to live.
  let facingLeft = w.sprites[player.idx].flipX
  let e = w.spawn({ckPosition, ckSprite, ckCollider, ckLifetime,
                   ckContactDamage})
  w.sprites[e.idx] = initStaticSprite(atlas, "weapon_knight_sword", scale)
  w.sprites[e.idx].flipX = facingLeft
  let px = w.positions[player.idx]
  w.positions[e.idx] = Vector2(
    x: if facingLeft: px.x - w.sprites[e.idx].width
       else: px.x + w.sprites[player.idx].width,
    y: px.y + 6)
  w.colliders[e.idx] = Collider(
    offset: Vector2(x: -6, y: -6),
    size: Vector2(x: w.sprites[e.idx].width + 12,
                  y: w.sprites[e.idx].height + 12),
    layer: lyPlayerAttack, hits: {lyEnemy})
  w.contactDamages[e.idx] = ContactDamage(amount: damage,
                                          knockback: 300)
  w.lifetimes[e.idx] = 0.15

proc spawnDamageNumber(w: var World, ev: DamageEvent) =
  ## A little number that jumps out of whoever got hurt, drifts up,
  ## and fades. Pure presentation, so it lives outside the systems.
  let e = w.spawn({ckPosition, ckVelocity, ckLifetime, ckFloatText})
  w.positions[e.idx] = ev.pos
  w.velocities[e.idx] = Vector2(x: 0, y: -30)
  w.lifetimes[e.idx] = 0.7
  w.floatTexts[e.idx] = $ev.amount

proc populateFloor(w: var World, d: Dungeon, atlas: Atlas,
                   floorNum: int, carryHp: int32): Entity =
  ## A fresh World for a fresh floor: the knight (keeping his hp from
  ## the stairs), enemies in every room but his, and the key.
  result = w.spawn({ckPosition, ckVelocity, ckSprite, ckActor,
                    ckPlayer, ckCollider, ckHealth})
  w.sprites[result.idx] = initAnimSprite(atlas, "knight_m_idle_anim", scale)
  w.actors[result.idx] = Actor(idleAnim: "knight_m_idle_anim",
                               runAnim: "knight_m_run_anim")
  w.colliders[result.idx] = feetCollider(
    w.sprites[result.idx], lyPlayer, hits = {lyPickup})
  w.healths[result.idx] = Health(hp: carryHp, maxHp: 6, invulnTime: 0.8)
  w.positions[result.idx] = d.roomCenter(d.startRoom) -
                            Vector2(x: 16, y: 28)
  let final = floorNum == floorCount
  let perRoom = min(2 + floorNum, 6)
  for i in 0 ..< d.rooms.len:
    if i != d.startRoom and not (final and i == d.stairsRoom):
      for _ in 1..perRoom:
        w.spawnEnemy(atlas, d.randomPosIn(i),
                     enemyKinds[rand(enemyKinds.high)].scaled(floorNum))
  if final:
    w.spawnBoss(atlas, d.roomCenter(d.stairsRoom) - Vector2(x: 32, y: 36))
  w.spawnKey(atlas, d.randomPosIn(d.keyRoom))

proc newRun(atlas: Atlas): Run =
  ## A whole playthrough, built from one seed.
  result.seed = int64(rand(1_000_000))
  echo "run seed: ", result.seed
  result.floorNum = 1
  result.swordPower = 1
  result.dropRng = initRand(result.seed xor 0x10071)
  result.crypt = generate(result.seed, 1, final = floorCount == 1)
  result.knight = result.world.populateFloor(result.crypt, atlas, 1,
                                             carryHp = 6)

proc descend(run: var Run, atlas: Atlas) =
  ## Down the stairs: a fresh floor, one deeper, hp carried along.
  inc run.floorNum
  let hp = run.world.healths[run.knight.idx].hp
  run.crypt = generate(run.seed + int64(run.floorNum)*7919, run.floorNum,
                       final = run.floorNum == floorCount)
  run.world = World()
  run.knight = run.world.populateFloor(run.crypt, atlas, run.floorNum,
                                       carryHp = hp)

proc drawCrown(cx, cy: int32, s: float32 = 1) =
  ## The Chapter 1 crown, drawn at any size: full for the title and
  ## victory screens, a third for the item lying in the throne room.
  ## Some programmer art is family.
  let left = float32(cx) - 60*s
  let top = float32(cy) - 40*s
  drawRectangle(int32(left), int32(top + 50*s), int32(120*s),
                int32(30*s), crownColor)
  for i in 0'i32..2'i32:
    let px = left + float32(i)*40*s
    drawTriangle(
      Vector2(x: px, y: top + 50*s),
      Vector2(x: px + 40*s, y: top + 50*s),
      Vector2(x: px + 20*s, y: top),
      crownColor)
  drawCircle(cx, cy + int32(25*s), 9*s, Color(r: 165, g: 48, b: 48, a: 255))

proc counted(n: int, word: string): string =
  ## "1 kill" but "2 kills": the two run-summary screens share this so
  ## neither of them ever brags about "1 kills".
  $n & " " & word & (if n == 1: "" else: "s")

proc drawCentered(text: string, y: int32, size: int32, color: Color) =
  drawText(text, (screenWidth - measureText(text, size)) div 2, y,
           size, color)

proc main =
  randomize()
  setConfigFlags(flags(WindowHighdpi, WindowResizable))
  initWindow(screenWidth, screenHeight, "Crypt of Nimrod")
  defer: closeWindow()
  initAudioDevice()
  defer: closeAudioDevice()
  setExitKey(KeyboardKey.Null)   # Esc pauses; it does not quit
  setTargetFPS(60)

  let target = loadCanvas(screenWidth, screenHeight)
  let atlas = loadAtlas(
    atlasDir & "0x72_DungeonTilesetII_v1.7.png",
    atlasDir & "tile_list_v1.7")
  let skin = makeSkin(atlas)
  let fx = loadFx(atlas, screenWidth, screenHeight)
  var bank = loadAudioBank()
  bank.startMusic()

  var phase = gpMenu
  var crtOn = false
  var run: Run                   # empty until the first game starts
  var dust: Particles            # world debris; survives runs, harmless
  var shake: Shake
  var hitstop: float32 = 0
  var cam = makeCamera(Vector2(x: screenWidth, y: screenHeight))
  var menuTime: float32 = 0
  var dbg = initDebug()

  while not windowShouldClose():
    bank.update()
    dbg.update()
    let rawDt = getFrameTime()*dbg.timeScale
    # Hitstop: a few frozen frames after a hit. The simulation stops;
    # the shake decay and music do not, or the freeze reads as a bug.
    hitstop -= rawDt
    let dt = if hitstop > 0: 0.0'f32 else: rawDt
    shake.update(rawDt)
    let vp = computeViewport(screenWidth, screenHeight)
    if wasPressed(aCrt):           # a display setting, so it works in
      crtOn = not crtOn            # every phase, even on the title screen

    # --- Update, by phase ---
    case phase
    of gpMenu:
      menuTime += dt
      if wasPressed(aAttack):
        run = newRun(atlas)
        cam.target = run.crypt.roomCenter(run.crypt.startRoom)
        phase = gpPlaying
        bank.play(sfxStart)
    of gpPaused:
      if wasPressed(aPause) or wasPressed(aAttack):
        phase = gpPlaying
    of gpGameOver, gpVictory:
      if wasPressed(aAttack):
        run = newRun(atlas)
        cam.target = run.crypt.roomCenter(run.crypt.startRoom)
        phase = gpPlaying
        bank.play(sfxStart)
    of gpPlaying:
      if wasPressed(aPause):
        phase = gpPaused
      if dbg.enabled:
        if isKeyPressed(T):
          run.world.positions[run.knight.idx] = mouseWorld(cam, vp)
        if isKeyPressed(E):
          run.world.spawnEnemy(atlas, mouseWorld(cam, vp),
                               enemyKinds[rand(enemyKinds.high)]
                               .scaled(run.floorNum))
      run.attackCooldown -= dt
      if wasPressed(aAttack) and run.attackCooldown <= 0:
        run.attackCooldown = attackCooldownTime
        run.world.swingSword(atlas, run.knight, run.swordPower)
        bank.play(sfxSwing)
      run.world.playerInputSystem(playerSpeed)
      run.world.aiSystem(run.knight, run.crypt)
      # --- the boss's turn: phase flip and minion calls ---
      var bossPos = Vector2()
      let bossIdx = run.world.findBoss()
      if bossIdx >= 0:
        bossPos = run.world.positions[bossIdx] + Vector2(x: 32, y: 36)
        let wasCalm = run.world.bosses[bossIdx].phase == bpStalk
        for spot in run.world.bossSystem(dt):
          # Cap the court: only creatures in the throne room count,
          # or the rest of the floor's population blocks the calls.
          var court = 0
          for i in run.world.query({ckAi}):
            if run.crypt.roomAt(run.world.positions[i]) ==
                run.crypt.stairsRoom:
              inc court
          if court <= 4:                 # the Warden counts as one
            run.world.spawnEnemy(atlas, spot + Vector2(x: 40, y: 40),
                                 imp.scaled(run.floorNum))
            dust.emitBurst(spot + Vector2(x: 56, y: 56), 8,
                           Color(r: 160, g: 60, b: 200, a: 255),
                           speed = 90, lifeSecs = 0.4)
        if wasCalm and run.world.bosses[bossIdx].phase == bpEnrage:
          bank.play(sfxRoar)             # half health: the fight changes
          shake.addTrauma(0.5)
      run.world.healthSystem(dt)
      run.world.movementSystem(run.crypt.map, dt, dbg.noclip)
      let hpBefore = run.world.healths[run.knight.idx].hp
      run.world.contactSystem()
      run.world.damageSystem()
      if run.world.damageEvents.len > 0:
        bank.play(sfxHit)
        hitstop = 0.05                   # three frames of impact
        shake.addTrauma(0.2)
      if run.world.healths[run.knight.idx].hp < hpBefore:
        shake.addTrauma(0.35)            # our pain shakes harder
      for ev in run.world.damageEvents:
        run.world.spawnDamageNumber(ev)
        dust.emitBurst(ev.pos, 6, Color(r: 255, g: 200, b: 100, a: 255),
                       speed = 70, lifeSecs = 0.35)
      for spot in run.world.deathSystem():
        inc run.kills
        bank.play(sfxKill)
        hitstop = 0.09                   # deaths hit harder
        shake.addTrauma(0.3)
        dust.emitBurst(spot + Vector2(x: 16, y: 16), 18,
                       Color(r: 200, g: 60, b: 60, a: 255),
                       speed = 110, lifeSecs = 0.6)
        let d = run.world.spawn({ckPosition, ckSprite, ckLifetime})
        run.world.sprites[d.idx] = initStaticSprite(atlas, "skull", scale)
        run.world.positions[d.idx] = spot
        run.world.lifetimes[d.idx] = 4
        let drop = enemyDrops.roll(run.dropRng)
        if drop.isSome:
          run.world.spawnLoot(atlas, spot + Vector2(x: 8, y: 8), drop.get)
      if bossIdx >= 0 and run.world.findBoss() < 0:
        # The Warden fell: the long freeze, the seals dissolve, and
        # the crown is suddenly just lying there.
        hitstop = 0.25
        shake.addTrauma(0.9)
        dust.emitBurst(bossPos, 40, crownColor, speed = 160,
                       lifeSecs = 0.9)
        run.world.spawnCrown(bossPos - Vector2(x: 19, y: 8))
        run.crypt.unlock()
        bank.play(sfxUnlock)
      if run.world.healths[run.knight.idx].hp <= 0:
        phase = gpGameOver       # death means something now
        bank.play(sfxGameOver)
      for kind in run.world.pickupSystem():
        case kind
        of pkCrown:
          phase = gpVictory      # the fifth arm the compiler demanded
          bank.play(sfxVictory)
        of pkCoin:
          inc run.coins
          bank.play(sfxCoin)
        of pkKey:
          run.crypt.unlock()
          bank.play(sfxUnlock)
        of pkHeart:
          run.world.applyPickup(run.knight, run.swordPower, kind)
          bank.play(sfxHeart)
        else:
          run.world.applyPickup(run.knight, run.swordPower, kind)
          bank.play(sfxPower)
      run.world.hoverSystem(mouseWorld(cam, vp))
      run.world.actorAnimSystem(atlas)
      run.world.animationSystem(dt)
      run.world.lifetimeSystem(dt)
      dust.update(dt)                    # frozen by hitstop, like the world
      let feet = run.world.colliderRect(run.knight.idx)
      if run.crypt.map.tileAt(
          int32(feet.x + feet.width/2) div tileSize,
          int32(feet.y + feet.height/2) div tileSize) == tkStairs:
        run.descend(atlas)
        bank.play(sfxStairs)
        dust = Particles()               # new floor, clean air
      let knightCenter = run.world.positions[run.knight.idx] + Vector2(
        x: run.world.sprites[run.knight.idx].width/2,
        y: run.world.sprites[run.knight.idx].height/2)
      let room = run.crypt.roomAt(knightCenter)
      if run.world.findBoss() >= 0 and room == run.crypt.stairsRoom and
          not run.crypt.isLocked and
          run.crypt.insideRoom(run.crypt.stairsRoom, knightCenter):
        run.crypt.relock()               # no stairs behind the Warden,
        bank.play(sfxStairs)             # and now no door behind you
        shake.addTrauma(0.4)
      let camTarget = if room >= 0: run.crypt.roomCenter(room)
                      else: knightCenter
      cam.follow(camTarget, run.crypt.map.pixelSize, dt, speed = 6)

    # --- Draw, pass 1: the frame, at its fixed logical resolution ---
    beginTextureMode(target)
    clearBackground(backgroundColor)
    if phase == gpMenu:
      let bob = int32(10*sin(menuTime*PI))
      drawCrown(screenWidth div 2, screenHeight div 2 - 40 + bob)
      drawCentered("CRYPT OF NIMROD", 300, 40, crownColor)
      drawCentered("press SPACE to descend", 350, 20, LightGray)
      drawCentered("WASD moves, SPACE swings, ESC pauses, C for CRT",
                   380, 10, Gray)
    else:
      # The camera drawn through this frame's shake displacement; the
      # real camera never moves, so the shake leaves no drift behind.
      var shakenCam = cam
      shakenCam.target = cam.target + shake.offset()
      beginMode2D(shakenCam)
      run.crypt.map.draw(atlas, skin)
      run.world.drawSystem(atlas, fx)
      for i in run.world.query({ckPickup, ckPosition}):
        if run.world.pickupKinds[i] == pkCrown:
          drawCrown(int32(run.world.positions[i].x) + 19,
                    int32(run.world.positions[i].y) + 12, 0.32)
      dust.draw()
      drawFloatingTexts(run.world)
      dbg.drawWorld(run.world)
      endMode2D()
      if run.world.hovered >= 0:
        let m = vp.mouseLogical()
        drawText(label(run.world.pickupKinds[run.world.hovered]),
                 int32(m.x) + 14, int32(m.y) - 6, 16, RayWhite)
      dbg.drawPanel(run.world, cam, vp)
      drawHud(atlas, run.crypt, run.crypt.roomAt(
                run.world.positions[run.knight.idx]),
              run.world.healths[run.knight.idx], run.coins,
              run.swordPower, run.floorNum, screenWidth)
      let bossNow = run.world.findBoss()
      if bossNow >= 0 and run.crypt.roomAt(
          run.world.positions[run.knight.idx]) == run.crypt.stairsRoom:
        drawBossBar("THE WARDEN", run.world.healths[bossNow].hp,
                    run.world.healths[bossNow].maxHp,
                    screenWidth, screenHeight)
      drawFPS(10, 10)
      if phase == gpPaused:
        drawRectangle(0, 0, screenWidth, screenHeight,
                      Color(r: 0, g: 0, b: 0, a: 160))
        drawCentered("PAUSED", 200, 40, RayWhite)
        drawCentered("ESC resumes", 250, 20, LightGray)
        drawCentered("C toggles the CRT filter", 280, 10, Gray)
      elif phase == gpGameOver:
        drawRectangle(0, 0, screenWidth, screenHeight,
                      Color(r: 0, g: 0, b: 0, a: 190))
        drawCentered("THE CRYPT KEEPS ITS CROWN", 160, 30, Red)
        drawCentered("floor " & $run.floorNum & "  |  " &
                     counted(run.kills, "kill") & "  |  " &
                     counted(run.coins, "coin"), 220, 20, LightGray)
        drawCentered("press SPACE to try again", 270, 20, Gold)
      elif phase == gpVictory:
        drawRectangle(0, 0, screenWidth, screenHeight,
                      Color(r: 0, g: 0, b: 0, a: 190))
        drawCrown(screenWidth div 2, 140)
        drawCentered("THE CROWN RETURNS", 250, 30, crownColor)
        drawCentered($floorCount & " floors  |  " &
                     counted(run.kills, "kill") & "  |  " &
                     counted(run.coins, "coin"), 300, 20, LightGray)
        drawCentered("press SPACE to run it back", 340, 20, Gold)
    endTextureMode()

    # --- Draw, pass 2: blit, integer-scaled, letterboxed ---
    # The CRT shader wraps only the blit: post-processing is exactly
    # "draw the finished frame through a fragment shader".
    beginDrawing()
    clearBackground(Black)
    if crtOn:
      beginShaderMode(fx.crt)
    drawTexture(target.texture,
      Rectangle(x: 0, y: 0, width: float32(screenWidth),
                height: -float32(screenHeight)),
      vp.dest, Vector2(x: 0, y: 0), 0, White)
    if crtOn:
      endShaderMode()
    endDrawing()

main()

## The bestiary: every enemy's base numbers, and how floors scale
## them. Moved out of the main module (Chapter 16) so the numbers are
## testable headless and balancing the game is editing one table.

type
  EnemyStats* = object
    name*: string       # atlas base name; anims are name & "_idle_anim" etc.
    hp*: int32
    speed*: float32     # chase speed, px/s
    aggro*: float32     # start chasing inside this range, px

const enemyKinds* = [
  EnemyStats(name: "goblin", hp: 2, speed: 85, aggro: 150),
  EnemyStats(name: "skelet", hp: 2, speed: 70, aggro: 170),
  EnemyStats(name: "imp",    hp: 1, speed: 95, aggro: 140),
  EnemyStats(name: "chort",  hp: 3, speed: 80, aggro: 160),
  EnemyStats(name: "ogre",   hp: 5, speed: 45, aggro: 190)]

const imp* = enemyKinds[2]   ## the boss's minion of choice: fast, frail

const warden* = EnemyStats(
  ## The boss. Slow and huge; the fight's pressure comes from the
  ## locked room, the contact damage, and the minions, not from
  ## outrunning the player. Aggro is bigger than the whole room:
  ## sensing is room-scoped (Chapter 10), so stepping into the
  ## throne room is starting the fight.
  name: "big_demon", hp: 20, speed: 55, aggro: 1000)

proc scaled*(s: EnemyStats, floorNum: int): EnemyStats =
  ## Per-floor difficulty: +1 hp every second floor, +8% speed per
  ## floor after the first. Gentle on purpose; the knight's own power
  ## (hearts, sword flasks) climbs too, and the fun lives in that
  ## race staying close.
  result = s
  result.hp = s.hp + int32((floorNum - 1) div 2)
  result.speed = s.speed*(1 + 0.08*float32(floorNum - 1))

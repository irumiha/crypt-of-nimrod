import std/strformat
import raylib
import sprites

type
  CompKind* = enum
    ckPosition, ckVelocity, ckSprite, ckLifetime

  Entity* = object
    ## A typed handle: a slot index plus the generation it was issued in.
    idx*: int32
    gen*: uint32

  World* = object
    masks: seq[set[CompKind]]     # which components each slot has
    gens: seq[uint32]             # bumped every time a slot is reused
    freeSlots: seq[int32]
    # One seq per component, all the same length. A slot owns row idx
    # in every one of them; the mask says which rows are meaningful.
    positions*: seq[Vector2]
    velocities*: seq[Vector2]
    sprites*: seq[AnimSprite]
    lifetimes*: seq[float32]

proc alive*(w: World, e: Entity): bool =
  e.idx < int32(w.gens.len) and w.gens[e.idx] == e.gen

proc entity*(w: World, idx: int32): Entity =
  ## The current handle for a slot index (used inside systems).
  Entity(idx: idx, gen: w.gens[idx])

proc entityCount*(w: World): int =
  w.masks.len - w.freeSlots.len

proc spawn*(w: var World, comps: set[CompKind]): Entity =
  var idx: int32
  if w.freeSlots.len > 0:
    idx = w.freeSlots.pop()
  else:
    idx = int32(w.masks.len)
    w.masks.add({})
    w.gens.add(0)
    w.positions.add(Vector2())
    w.velocities.add(Vector2())
    w.sprites.add(AnimSprite())
    w.lifetimes.add(0)
  w.masks[idx] = comps
  Entity(idx: idx, gen: w.gens[idx])

proc despawn*(w: var World, e: Entity) =
  if w.alive(e):
    w.masks[e.idx] = {}
    inc w.gens[e.idx]           # every old handle to this slot goes stale
    w.freeSlots.add(e.idx)

iterator query*(w: World, comps: set[CompKind]): int32 =
  ## Every live slot that has at least the requested components.
  for i in 0 ..< w.masks.len:
    if comps <= w.masks[i]:
      yield int32(i)

proc dump*(w: World, e: Entity): string =
  ## The whole entity, reassembled for inspection.
  if not w.alive(e):
    return &"entity {e.idx}: dead (stale handle, gen {e.gen})"
  result = &"entity {e.idx} (gen {e.gen})"
  let m = w.masks[e.idx]
  if ckPosition in m:
    let p = w.positions[e.idx]
    result.add &"\n  position  ({p.x:.1f}, {p.y:.1f})"
  if ckVelocity in m:
    let v = w.velocities[e.idx]
    result.add &"\n  velocity  ({v.x:.1f}, {v.y:.1f})"
  if ckSprite in m:
    result.add &"\n  sprite    {w.sprites[e.idx].width.int}x" &
               &"{w.sprites[e.idx].height.int} px on screen"
  if ckLifetime in m:
    result.add &"\n  lifetime  {w.lifetimes[e.idx]:.2f}s left"

## The game's entity-component-system, all of it.
##
## An entity is a slot index plus a generation. Components are columns:
## one seq per component type, all the same length, with a per-slot
## bitset mask saying which columns apply. Queries scan the masks.
## Deliberately not generic and not a library; it knows this game's
## components by name, and adding one is a three-line diff.

import std/strformat
import raylib
import sprites

type
  CompKind* = enum
    ckPosition, ckVelocity, ckSprite, ckLifetime, ckActor, ckPlayer,
    ckCollider, ckBounce, ckHealth, ckAi, ckContactDamage,
    ckPickup

  Layer* = enum
    ## What a collider *is*. Its `hits` set says what it cares about.
    lyPlayer, lyEnemy, lyPickup, lyPlayerAttack

  Collider* = object
    ## An axis-aligned box, relative to the entity's position. The
    ## layer/hits pair filters interactions: A touches B only when
    ## B's layer is in A's hits.
    offset*: Vector2
    size*: Vector2
    layer*: Layer
    hits*: set[Layer]

  Health* = object
    ## Hit points plus the two timers that make combat readable:
    ## invuln blocks repeat damage after a hit, stun takes control
    ## away while knockback plays out.
    hp*, maxHp*: int32
    invuln*: float32      # damage immunity remaining, seconds
    invulnTime*: float32  # immunity granted per hit taken
    stun*: float32        # no self-control while > 0

  AiState* = enum
    asWander, asChase

  Ai* = object
    ## A one-enum state machine. Wander keeps whatever velocity the
    ## bounce behavior maintains; chase steers at the player.
    state*: AiState
    chaseSpeed*: float32
    aggro*: float32       # start chasing inside this range, px

  PickupKind* = enum
    pkCoin, pkKey

  ContactDamage* = object
    ## "Touching me hurts": on contact, the victim loses hp and gets
    ## shoved. Carried by enemies and by sword swings alike.
    amount*: int32
    knockback*: float32

  Actor* = object
    ## Which animations a character switches between. Data only; the
    ## switching itself happens in actorAnimSystem.
    idleAnim*: string
    runAnim*: string

  Entity* = object
    ## A typed handle: a slot index plus the generation it was issued
    ## in. If the slot has been despawned and reused since, the
    ## generations no longer match and the handle is stale (see alive).
    idx*: int32
    gen*: uint32

  Contact* = tuple[a, b: Entity]

  World* = object
    masks: seq[set[CompKind]]     # which components each slot has
    gens: seq[uint32]             # bumped every time a slot is reused
    freeSlots: seq[int32]
    # One seq per component, all the same length. A slot owns row idx
    # in every one of them; the mask says which rows are meaningful.
    # ckPlayer and ckBounce are tags: mask-only, no column at all.
    positions*: seq[Vector2]
    velocities*: seq[Vector2]
    sprites*: seq[AnimSprite]
    lifetimes*: seq[float32]
    actors*: seq[Actor]
    colliders*: seq[Collider]
    healths*: seq[Health]
    ais*: seq[Ai]
    contactDamages*: seq[ContactDamage]
    pickupKinds*: seq[PickupKind]
    # Frame scratch, not a component: contact pairs found this frame,
    # rewritten by contactSystem and read by whoever cares.
    contacts*: seq[Contact]

proc alive*(w: World, e: Entity): bool =
  ## True while the handle still refers to the entity it was issued
  ## for. A despawned (or despawned-and-reused) slot fails the
  ## generation check, so stale handles read as dead instead of
  ## pointing at whoever lives there now.
  e.idx < int32(w.gens.len) and w.gens[e.idx] == e.gen

proc has*(w: World, idx: int32, c: CompKind): bool =
  ## Whether a slot currently has a component (for the occasional
  ## per-entity branch inside a system).
  c in w.masks[idx]

proc entity*(w: World, idx: int32): Entity =
  ## The current handle for a slot index (used inside systems, where
  ## queries yield raw indices).
  Entity(idx: idx, gen: w.gens[idx])

proc entityCount*(w: World): int =
  ## Live entities right now (allocated slots minus the free list).
  w.masks.len - w.freeSlots.len

proc spawn*(w: var World, comps: set[CompKind]): Entity =
  ## Claims a slot (reusing a despawned one when available), stamps it
  ## with the component mask, and returns its handle. Component data
  ## is whatever the constructor defaults are; the caller fills in the
  ## columns it declared.
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
    w.actors.add(Actor())
    w.colliders.add(Collider())
    w.healths.add(Health())
    w.ais.add(Ai())
    w.contactDamages.add(ContactDamage())
    w.pickupKinds.add(pkCoin)
  w.masks[idx] = comps
  Entity(idx: idx, gen: w.gens[idx])

proc despawn*(w: var World, e: Entity) =
  ## Retires an entity: clears its mask, invalidates every existing
  ## handle to it, and files the slot for reuse. The component data is
  ## left in place, unreachable, until the next tenant overwrites it.
  ## Never call this while iterating a query; collect first (see
  ## lifetimeSystem for the pattern).
  if w.alive(e):
    w.masks[e.idx] = {}
    inc w.gens[e.idx]           # every old handle to this slot goes stale
    w.freeSlots.add(e.idx)

iterator query*(w: World, comps: set[CompKind]): int32 =
  ## Every live slot that has at least the requested components.
  ## `<=` is the bitset subset test: one AND and one compare per slot.
  ## Dead slots have mask {} and never match. Scans every slot ever
  ## allocated, which at this game's scale is nanoseconds.
  for i in 0 ..< w.masks.len:
    if comps <= w.masks[i]:
      yield int32(i)

proc colliderRect*(w: World, idx: int32): Rectangle =
  ## The collider's box in world coordinates, ready for overlap tests.
  Rectangle(
    x: w.positions[idx].x + w.colliders[idx].offset.x,
    y: w.positions[idx].y + w.colliders[idx].offset.y,
    width: w.colliders[idx].size.x,
    height: w.colliders[idx].size.y)

proc feetCollider*(s: AnimSprite, layer: Layer,
                   hits: set[Layer] = {}): Collider =
  ## The bottom half of a sprite's box: collide with the feet, draw
  ## the body. Keeps a character's head free to overlap wall tiles
  ## above it, which reads correctly in a top-down view.
  Collider(offset: Vector2(x: 0, y: s.height/2),
           size: Vector2(x: s.width, y: s.height/2),
           layer: layer, hits: hits)

proc dump*(w: World, e: Entity): string =
  ## The whole entity, reassembled for inspection: the answer to "ECS
  ## smears my entity across four arrays." Keep this current as
  ## components get added; it is the debugging tool this architecture
  ## owes you.
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
  if ckActor in m:
    result.add &"\n  actor     idle={w.actors[e.idx].idleAnim} " &
               &"run={w.actors[e.idx].runAnim}"
  if ckCollider in m:
    let c = w.colliders[e.idx]
    result.add &"\n  collider  {c.size.x.int}x{c.size.y.int} at " &
               &"+{c.offset.x.int},+{c.offset.y.int} " &
               &"layer={c.layer} hits={c.hits}"
  if ckHealth in m:
    let h = w.healths[e.idx]
    result.add &"\n  health    {h.hp}/{h.maxHp} hp " &
               &"(invuln {h.invuln:.2f}s, stun {h.stun:.2f}s)"
  if ckAi in m:
    result.add &"\n  ai        {w.ais[e.idx].state} " &
               &"speed={w.ais[e.idx].chaseSpeed:.0f} " &
               &"aggro={w.ais[e.idx].aggro:.0f}"
  if ckContactDamage in m:
    result.add &"\n  damage    {w.contactDamages[e.idx].amount} on touch, " &
               &"knockback {w.contactDamages[e.idx].knockback:.0f}"
  if ckPickup in m:
    result.add &"\n  pickup    {w.pickupKinds[e.idx]}"
  if ckPlayer in m:
    result.add "\n  player    (tag: mask bit only, no data)"
  if ckBounce in m:
    result.add "\n  bounce    (tag: reflects off walls)"

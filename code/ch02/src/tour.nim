## The Chapter 2 language tour. Pure Nim, no raylib.
## Run it with:  nimble tour   (or: nim r src/tour.nim)
## Every snippet in the chapter lives here; vandalize freely.
import std/[tables, strformat]

# --- Bindings: let, var, const ------------------------------------------

const maxFloors = 8            # compile-time, baked into the binary
let playerName = "Nimrod"      # runtime, immutable (this is your default)
var gold = 0                   # runtime, mutable (needs a reason)
gold += 30

# Types are inferred, but present and static. This does not compile:
# gold = "thirty"

# --- Procs, UFCS, and expressions ---------------------------------------

proc healthColor(fraction: float): string =
  if fraction > 0.5: "green"
  elif fraction > 0.2: "yellow"
  else: "red"

proc quote(s: string, mark = "\""): string =
  mark & s & mark

echo healthColor(0.7)            # classic call: green
echo 0.7.healthColor             # same proc, method-call syntax: green
echo 0.7.healthColor.quote       # chains without a builder in sight
echo "ow".quote(mark = "!")      # named arguments: !ow!

# `if` is an expression; the last expression is the return value.
let mood = if gold > 0: "optimistic" else: "filing a ticket"
echo mood                        # optimistic

# --- Objects are values -------------------------------------------------

type
  Potion = object
    name: string
    doses: int

var mine = Potion(name: "healing", doses: 3)
var yours = mine                 # a copy. A real one. The whole potion.
yours.doses = 0
echo mine.doses                  # 3 — your drinking problem, not mine

proc drink(p: var Potion) =      # `var` parameter: mutation, but visible
  if p.doses > 0: dec p.doses

mine.drink()
echo mine.doses                  # 2

# --- ref objects share, like Java objects always do ----------------------

type
  PartyChest = ref object
    gold: int

let chest = PartyChest(gold: 100)
let sameChest = chest            # same chest, second handle
sameChest.gold -= 60
echo chest.gold                  # 40 — welcome home, reference semantics

# --- Enums, sets, and exhaustive case ------------------------------------

type
  Element = enum
    Fire, Frost, Poison, Holy

proc verb(e: Element): string =
  case e                         # no default branch: the compiler checks
  of Fire: "burns"               # that every Element is handled
  of Frost: "chills"
  of Poison: "stacks"
  of Holy: "smites"

let resists: set[Element] = {Frost, Holy}   # a bitset, one bit per value
echo Poison in resists           # false
echo verb(Frost)                 # chills

# --- seq and Table --------------------------------------------------------

var inventory = @["sword", "rope"]
inventory.add("lantern")
echo inventory.len               # 3
echo inventory[^1]               # lantern — ^1 indexes from the end

var prices = {"sword": 50, "rope": 3}.toTable
prices["lantern"] = 12
echo prices.getOrDefault("shield")   # 0 — and no NullPointerException

# --- Iterators -------------------------------------------------------------

iterator floors(top: int): string =
  for n in 1..top:
    yield &"floor {n} of {top}"   # &"" is string interpolation

for f in floors(3):
  echo f                          # floor 1 of 3 ... floor 3 of 3

# mitems yields mutable references into the seq — no index bookkeeping.
var damage = @[10, 12, 7]
for d in damage.mitems:
  d *= 2
echo damage                       # @[20, 24, 14]

# --- Object variants: one type, several shapes ------------------------------

type
  LootKind = enum Coins, Weapon
  Loot = object
    case kind: LootKind           # the compiler guards field access
    of Coins:
      amount: int
    of Weapon:
      name: string
      damage: int

proc describe(loot: Loot): string =
  case loot.kind
  of Coins: &"{loot.amount} coins"
  of Weapon: &"{loot.name} ({loot.damage} dmg)"

echo describe(Loot(kind: Coins, amount: 42))            # 42 coins
echo describe(Loot(kind: Weapon, name: "axe", damage: 7))  # axe (7 dmg)

# --- Generics, briefly -------------------------------------------------------

proc lastOr[T](s: seq[T], fallback: T): T =
  if s.len > 0: s[^1] else: fallback

echo lastOr(@[3, 1, 4], 0)        # 4
echo lastOr(newSeq[string](), "empty")   # empty — resolved at compile time

echo &"{playerName} leaves with {gold} gold across {maxFloors} floors"

## Headless tests for the feel systems: particles are arithmetic over
## parallel arrays, shake is one decaying number, and both have
## invariants worth pinning.

import std/unittest
import raylib, raymath
import camera, particles

suite "particles":
  test "a burst adds exactly count particles":
    var p: Particles
    p.emitBurst(Vector2(x: 0, y: 0), 25, Red, speed = 100)
    check p.len == 25

  test "expiry compacts every parallel array in lockstep":
    var p: Particles
    p.emitBurst(Vector2(x: 0, y: 0), 40, Red, speed = 100,
                lifeSecs = 0.2)
    # Max life is 0.2, min is 0.1 (the 0.5..1.0 spread), so:
    p.update(0.05)
    check p.len == 40          # too early for anyone
    p.update(0.30)
    check p.len == 0           # too late for everyone
    p.emitBurst(Vector2(x: 0, y: 0), 10, Red, speed = 100)
    check p.len == 10          # arrays still usable after compaction

  test "drag slows debris down":
    var p: Particles
    p.emitBurst(Vector2(x: 0, y: 0), 1, Red, speed = 100, lifeSecs = 5)
    let before = length(p.body(0).vel)
    p.update(0.1)
    check length(p.body(0).vel) < before

suite "screen shake":
  test "trauma accumulates, clamps at one, and decays to zero":
    var s: Shake
    s.addTrauma(0.7)
    s.addTrauma(0.7)
    check s.trauma == 1.0
    s.update(0.5)
    check abs(s.trauma - 0.25) < 0.001
    s.update(10)
    check s.trauma == 0.0

  test "displacement is bounded by trauma squared":
    var s: Shake
    s.addTrauma(0.5)             # trauma^2 = 0.25, max 6 px -> 1.5
    for _ in 1..100:
      let o = s.offset()
      check abs(o.x) <= 1.5
      check abs(o.y) <= 1.5

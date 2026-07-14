## Headless tests for the synthesizer: the sounds are arithmetic, so
## their invariants are checkable without an audio device.

import std/unittest
import raylib
import audio

suite "the synthesizer":
  test "a tone is the right length and fades to silence":
    let t = tone(440, 440, 0.5, shSine, volume = 0.5)
    check t.len == 22050                 # half a second at 44100 Hz
    check abs(t[^1]) < 500               # envelope ends near zero
    var peak = 0
    for s in t:
      peak = max(peak, abs(int(s)))
    check peak > 10_000                  # and it is not silence
    check peak <= 16_000                 # 0.5 volume of 32000

  test "pure shapes are deterministic":
    check tone(440, 220, 0.1, shSquare) == tone(440, 220, 0.1, shSquare)

  test "mix takes the length of the longest track and clips politely":
    let long = tone(200, 200, 0.3, shSquare, volume = 0.9)
    let short = tone(400, 400, 0.1, shSquare, volume = 0.9)
    let m = mix(long, short)
    check m.len == long.len
    for s in m:
      check abs(int(s)) <= 32000         # saturating add never wraps

  test "the WAV wrapper writes a well-formed header":
    let samples = tone(440, 440, 0.1, shSine)
    let wav = buildWav(samples)
    check wav.len == 44 + samples.len*2
    check wav[0..3] == @[82'u8, 73, 70, 70]    # "RIFF"
    check wav[8..11] == @[87'u8, 65, 86, 69]   # "WAVE"
    # sample rate field, little endian, at offset 24
    let rate = int(wav[24]) or (int(wav[25]) shl 8) or
               (int(wav[26]) shl 16) or (int(wav[27]) shl 24)
    check rate == 44100

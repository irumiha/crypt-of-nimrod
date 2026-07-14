## Every sound in the game, synthesized from arithmetic at startup.
## No files, no licensing, no asset pipeline: a square wave is a loop
## and an if. This is the sfxr/chiptune lineage, in miniature.
##
## The synth builds 16-bit mono samples, wraps them in a WAV header
## by hand (44 bytes of 1991-vintage file format), and hands them to
## raylib. Music is the same trick streamed on a loop.

import std/[math, random]
import raylib

const sampleRate = 44100

type
  Shape* = enum
    shSquare, shSine, shTriangle, shNoise

  Sfx* = enum
    sfxSwing, sfxHit, sfxCoin, sfxHeart, sfxPower, sfxUnlock,
    sfxStairs, sfxKill, sfxGameOver, sfxStart

  AudioBank* = object
    sounds: array[Sfx, Sound]
    music: Music
    musicData: seq[uint8]   # the stream reads from this; keep it alive

proc tone*(freqStart, freqEnd, duration: float32, shape: Shape,
          volume = 0.5'f32): seq[int16] =
  ## One note: frequency slides from start to end, amplitude decays
  ## linearly to silence. Enough knobs for every effect we need.
  let n = int(duration*sampleRate)
  var phase = 0.0'f32
  for i in 0 ..< n:
    let t = float32(i)/float32(n)
    let freq = freqStart + (freqEnd - freqStart)*t
    phase += freq/sampleRate
    let raw = case shape
      of shSquare: (if phase mod 1.0 < 0.5: 1.0'f32 else: -1.0)
      of shSine: sin(phase*2*PI)
      of shTriangle: abs(phase mod 1.0 - 0.5)*4 - 1
      of shNoise: rand(2.0'f32) - 1
    let envelope = 1 - t             # linear fade-out
    result.add(int16(raw*envelope*volume*32000))

proc mix*(tracks: varargs[seq[int16]]): seq[int16] =
  ## Overlays tracks sample-by-sample (saturating, crudely).
  for tr in tracks:
    if tr.len > result.len:
      result.setLen(tr.len)
  for tr in tracks:
    for i, s in tr:
      result[i] = int16(clamp(int32(result[i]) + int32(s), -32000, 32000))

proc buildWav*(samples: seq[int16]): seq[uint8] =
  ## A minimal WAV: 44-byte RIFF header, then the PCM data. Little
  ## endian throughout, which x86 gives us for free.
  proc add32(s: var seq[uint8], v: uint32) =
    s.add(uint8(v and 0xff))
    s.add(uint8((v shr 8) and 0xff))
    s.add(uint8((v shr 16) and 0xff))
    s.add(uint8((v shr 24) and 0xff))
  proc add16(s: var seq[uint8], v: uint16) =
    s.add(uint8(v and 0xff))
    s.add(uint8((v shr 8) and 0xff))
  let dataSize = uint32(samples.len*2)
  for c in "RIFF": result.add(uint8(c))
  result.add32(36 + dataSize)
  for c in "WAVE": result.add(uint8(c))
  for c in "fmt ": result.add(uint8(c))
  result.add32(16)          # fmt chunk size
  result.add16(1)           # PCM
  result.add16(1)           # mono
  result.add32(sampleRate)
  result.add32(sampleRate*2) # byte rate
  result.add16(2)           # block align
  result.add16(16)          # bits per sample
  for c in "data": result.add(uint8(c))
  result.add32(dataSize)
  for s in samples:
    result.add(uint8(uint16(s) and 0xff))
    result.add(uint8((uint16(s) shr 8) and 0xff))

proc toSound(samples: seq[int16]): Sound =
  loadSoundFromWave(loadWaveFromMemory(".wav", buildWav(samples)))

proc cryptTheme(): seq[int16] =
  ## Eight bars of A-minor gloom at 120 bpm: a pulsing square bass and
  ## a sine arpeggio. Three sine waves in a trench coat, but it loops.
  const eighth = 0.25'f32              # seconds per eighth note
  const a2 = 110.0'f32
  # Chord roots (Am, Am, F, G), as multiples of A2.
  const roots = [1.0'f32, 1.0, 1.3348, 1.4983]
  const arpeggio = [1.0'f32, 1.1892, 1.4983, 2.0]  # minor-ish spread
  for bar in 0 ..< 8:
    let root = a2*roots[(bar div 2) mod roots.len]
    for step in 0 ..< 8:
      let bass = tone(root/2, root/2, eighth, shSquare, volume = 0.10)
      let lead = tone(root*arpeggio[step mod 4],
                      root*arpeggio[step mod 4], eighth, shSine,
                      volume = 0.13)
      result.add(mix(bass, lead))

proc loadAudioBank*(): AudioBank =
  ## Synthesizes the entire soundscape. Takes a few milliseconds; the
  ## crypt's audio budget is one proc.
  result.sounds[sfxSwing] = toSound(tone(900, 200, 0.10, shNoise, 0.30))
  result.sounds[sfxHit] = toSound(tone(180, 70, 0.18, shSquare, 0.40))
  result.sounds[sfxCoin] = toSound(tone(900, 1500, 0.09, shSine, 0.35))
  result.sounds[sfxHeart] = toSound(tone(500, 900, 0.16, shSine, 0.35))
  result.sounds[sfxPower] = toSound(mix(
    tone(400, 400, 0.08, shSquare, 0.25),
    tone(600, 600, 0.16, shSquare, 0.18)))
  result.sounds[sfxUnlock] = toSound(tone(400, 1200, 0.45, shTriangle, 0.35))
  result.sounds[sfxStairs] = toSound(tone(500, 180, 0.35, shTriangle, 0.35))
  result.sounds[sfxKill] = toSound(tone(600, 60, 0.22, shNoise, 0.35))
  result.sounds[sfxGameOver] = toSound(tone(220, 40, 0.9, shSquare, 0.35))
  result.sounds[sfxStart] = toSound(mix(
    tone(440, 440, 0.1, shSquare, 0.2),
    tone(660, 660, 0.22, shSquare, 0.15)))
  result.musicData = buildWav(cryptTheme())
  result.music = loadMusicStreamFromMemory(".wav", result.musicData)

proc play*(bank: var AudioBank, sfx: Sfx) =
  playSound(bank.sounds[sfx])

proc startMusic*(bank: var AudioBank) =
  playMusicStream(bank.music)
  setMusicVolume(bank.music, 0.6)

proc update*(bank: var AudioBank) =
  ## Music streams in small buffers; somebody has to keep pouring.
  updateMusicStream(bank.music)

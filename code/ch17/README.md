# Chapter 17 — Shipping It

Game state at the end of this chapter: the same game, portable. One
structural change makes the web build possible (the frame is a proc,
the game's state is a `Game` object, because in a browser the event
loop owns the program), and the rest is packaging: a `nimble web`
task that compiles the whole game to a ~1.2 MB WebAssembly bundle,
plus the repo's release workflows — three desktop platforms on a tag,
GitHub Pages on every push.

Build and run: `nimble run` — tests: `nimble test`

Web build (with the [emsdk](https://emscripten.org) environment
active): `nimble web`, then serve `web/` with any static file server,
e.g. `python3 -m http.server -d web`.

## Changes from ch16

| File | Status | Notes |
|------|--------|-------|
| `web/shell.html` | new | the page the game embeds into: a canvas, a loading line, no external requests |
| `config.nims` | changed | emscripten target block: GLSL-ES 2, emcc as the C compiler, asset preloading, the memory-growth flags with their war story |
| `crypt_of_nimrod.nimble` | changed | + `task web` |
| `src/crypt_of_nimrod.nim` | changed | main restructured: `Game` object + `frame(g)` proc (template aliases keep the body verbatim); desktop keeps the `while` loop, the web hands `frame` to `emscriptenSetMainLoop` |
| `.github/workflows/release.yml` | new (repo root) | tag → Linux/Windows/macOS zips attached to a GitHub release |
| `.github/workflows/pages.yml` | new (repo root) | push → WebAssembly build deployed to GitHub Pages |
| everything else | unchanged | |

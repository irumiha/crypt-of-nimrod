# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config

# The web build: nim c -d:emscripten -d:release src/crypt_of_nimrod.nim
# (with the emsdk environment active). Output lands in web/ next to
# the checked-in shell page.
when defined(emscripten):
  --define:GraphicsApiOpenGlEs2   # WebGL 1 is OpenGL ES 2 in a trench coat
  --os:linux
  --cpu:wasm32
  --cc:clang
  --clang.exe:emcc
  --clang.linkerexe:emcc
  --clang.cpp.exe:emcc
  --clang.cpp.linkerexe:emcc
  --threads:off   # pthreads need COOP/COEP headers; GitHub Pages sends none
  --panics:on
  --define:noSignalHandler
  --passL:"-o web/index.html"
  --passL:"--shell-file web/shell.html"
  --passL:"--preload-file assets"
  --passL:"--preload-file shaders"
  # Growable heap, but grown the classic way (replace the buffer, not
  # a resizable ArrayBuffer): WebGL refuses texture uploads from views
  # over resizable buffers, which is a lesson we paid one afternoon for.
  --passL:"-s ALLOW_MEMORY_GROWTH=1"
  --passL:"-s GROWABLE_ARRAYBUFFERS=0"

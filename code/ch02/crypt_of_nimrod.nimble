# Package

version       = "0.1.0"
author        = "Igor Rumiha"
description   = "Crypt of Nimrod — a top-down action roguelite"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["crypt_of_nimrod"]

# Dependencies

requires "nim >= 2.0.0"
requires "naylib"

task tour, "Run the Chapter 2 language tour":
  exec "nim r src/tour.nim"

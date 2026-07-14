# The game's modules live one directory up. Dependency paths (naylib)
# come from `nimble test` itself; run tests through nimble.
switch("path", thisDir() & "/../src")

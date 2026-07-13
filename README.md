# Crypt of Nimrod

A top-down action roguelite written in [Nim](https://nim-lang.org) with
[raylib](https://www.raylib.com) (via the excellent
[naylib](https://github.com/planetis-m/naylib) binding).

Descend the crypt. Fight what lives there. Reclaim the crown.

This is the companion repository for the book *(title in progress)* — a book
about building games in Nim for people whose day job is Java, C#, or something
equally beige. Each chapter of the book leaves the game in a complete,
playable state, and this repo contains a snapshot of the game at the end of
every chapter.

## Repository layout

```
crypt-of-nimrod/
├── code/
│   ├── ch01/        # the game as it stands at the end of Chapter 1
│   ├── ch02/        # …Chapter 2, and so on
│   └── …
├── assets/          # canonical copy of all art & audio (CC0)
├── tools/           # maintenance scripts (build everything, sync assets)
└── .github/         # CI and release workflows
```

**Every `code/chNN/` directory is a complete, self-contained project** — its
own Nimble file, its own copy of the assets. There is nothing above it that
it needs. The top-level `assets/` directory is only the canonical copy the
authors edit; a script mirrors it into every chapter.

## Prerequisites

You need Nim (stable) and Nimble. The painless way is
[choosenim](https://github.com/nim-lang/choosenim):

```sh
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
```

On **Linux**, raylib builds from source and needs the usual windowing and
audio development headers. On Debian/Ubuntu:

```sh
sudo apt install libasound2-dev libx11-dev libxrandr-dev libxi-dev \
  libgl1-mesa-dev libglu1-mesa-dev libxcursor-dev libxinerama-dev \
  libwayland-dev libxkbcommon-dev
```

(Other distros: see the [raylib wiki](https://github.com/raysan5/raylib/wiki/Working-on-GNU-Linux).)

On **Windows** and **macOS** there is nothing extra to install.

## Building and running a chapter

Pick a chapter, go there, run it:

```sh
cd code/ch05
nimble run
```

That's the whole ceremony.

## Making it your own

You bought the book (thank you), you built the game, and now you want to take
it somewhere the book doesn't go. Any chapter directory works as a standalone
project — copy it out and it is yours:

```sh
cp -r code/ch16 ~/projects/my-game
cd ~/projects/my-game
git init
nimble run
```

No paths to fix, no assets to hunt down, no build scripts to adapt. From here
on it's a perfectly normal Nim project that happens to have a great backstory.

If you want your friends to play it, steal our release pipeline too: copy
`.github/workflows/release.yml` into your repo, push a tag, and GitHub builds
Windows, Linux, macOS, and browser versions for you. Chapter 16 of the book
walks through how it works.

## Assets

All art and audio is CC0 (public domain). Individual packs and their sources
are credited in [assets/README.md](assets/README.md). You can ship them, remix
them, or replace them with your own programmer art — no strings attached.

## License

The code is MIT licensed — see [LICENSE](LICENSE). Build something with it.

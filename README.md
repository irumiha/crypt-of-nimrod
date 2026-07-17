# Crypt of Nimrod

> **Archived, and left up on purpose.**
>
> This is the Nim version of the game and it is finished: seventeen
> chapters, each leaving a complete playable build, plus the headless
> tests, the release workflows and the WebAssembly port. It compiles and
> it plays.
>
> The book it was written for carried on in Odin, as
> [**Crypt of Odin**](https://github.com/irumiha/crypt-of-odin) — same
> game, same chapter ladder, different language. I switched for my own
> iteration loop, wanting sub-second builds and editor tooling I could
> lean on, and not because there is anything wrong with the code here. If
> you write games in Nim, this repository is probably more use to you than
> that one.
>
> Read-only since 2026-07-17 and not maintained. The code is MIT and the
> assets are CC0, so take whatever is useful.

A top-down action roguelite written in [Nim](https://nim-lang.org) with
[raylib](https://www.raylib.com) (via the excellent
[naylib](https://github.com/planetis-m/naylib) binding).

Descend the crypt and reclaim the crown.

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

## Making it your own

You got the book (thank you), you built the game, and now you want to take
it somewhere the book doesn't go. Any chapter directory works as a standalone
project — copy it out and it is yours:

```sh
cp -r code/ch17 ~/projects/my-game
cd ~/projects/my-game
git init
nimble run
```

There are no paths to fix and no build scripts to adapt. From here on it is
an ordinary Nim project.

If you want your friends to play it, steal our release pipeline too:
`.github/workflows/release.yml` builds Windows, Linux, and macOS zips when
you push a tag (`git tag v1.0 && git push --tags`), and
`.github/workflows/pages.yml` publishes the browser version to GitHub Pages
on every push to main. One repository setting first (Settings → Pages →
Source: "GitHub Actions") and your fork has a URL. Chapter 17 of the book
walks through both.

## Assets

All art and audio is CC0 (public domain). Individual packs and their sources
are credited in [assets/README.md](assets/README.md). You can ship them,
remix them, or replace them with your own.

## License

The code is MIT licensed — see [LICENSE](LICENSE). Build something with it.

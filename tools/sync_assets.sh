#!/usr/bin/env bash
# Mirror the canonical top-level assets/ into every chapter directory.
#
# Each code/chNN/ carries its own full copy of the assets so that a chapter
# can be copied out of this repo and used as a standalone project. Git stores
# identical files as a single blob, so the duplication costs almost nothing
# in repository size. Run this after any change to assets/; CI verifies the
# copies match (see .github/workflows/ci.yml, job "assets-in-sync").
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
shopt -s nullglob
chapters=("$root"/code/ch*/)

if [ ${#chapters[@]} -eq 0 ]; then
  echo "No chapters in code/ yet."
  exit 0
fi

for ch in "${chapters[@]}"; do
  rsync -a --delete --exclude 'README.md' "$root/assets/" "${ch}assets/"
  echo "synced $(basename "$ch")/assets"
done

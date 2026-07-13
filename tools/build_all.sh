#!/usr/bin/env bash
# Build every chapter snapshot. What CI does, but on your machine.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
shopt -s nullglob
chapters=("$root"/code/ch*/)

if [ ${#chapters[@]} -eq 0 ]; then
  echo "No chapters in code/ yet."
  exit 0
fi

failed=()
for ch in "${chapters[@]}"; do
  name=$(basename "$ch")
  echo "==> Building $name"
  if ! (cd "$ch" && nimble build -Y); then
    failed+=("$name")
  fi
done

if [ ${#failed[@]} -gt 0 ]; then
  echo "FAILED: ${failed[*]}"
  exit 1
fi
echo "All ${#chapters[@]} chapters build."

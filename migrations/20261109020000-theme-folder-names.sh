#!/usr/bin/env bash
# Migration: a theme's pictures for the Sky live in skies/ and its picture for the Palette is sample.png.
# Rename them in the themes you made yourself (~/.config/takumi/themes); nothing is overwritten.
set -euo pipefail
for t in "$HOME/.config/takumi/themes"/*/; do
  [[ -d "$t" ]] || continue
  if [[ -d "$t/backgrounds" && ! -e "$t/skies" ]]; then mv "$t/backgrounds" "$t/skies"; fi
  if [[ -f "$t/preview.png" && ! -e "$t/sample.png" ]]; then mv "$t/preview.png" "$t/sample.png"; fi
done
exit 0

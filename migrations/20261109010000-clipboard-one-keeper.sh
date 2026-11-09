#!/usr/bin/env bash
# Migration: the clipboard history has one keeper, takumi-clipboard.service, which leaves out what a
# password manager marks as sensitive. An older defaults.kdl also started a plain `cliphist store` that kept
# everything, passwords included; that line goes (docs/palette.md). takumi settings reset replaces the file
# anyway.
set -euo pipefail
f="$HOME/.config/niri/takumi/defaults.kdl"
[[ -f "$f" ]] || exit 0
grep -q '^spawn-at-startup "wl-paste" "--watch" "cliphist" "store"' "$f" || exit 0
cp "$f" "$f.bak-$(date +%Y%m%d%H%M%S)"
grep -v '^spawn-at-startup "wl-paste" "--watch" "cliphist" "store"' "$f" > "$f.new" && mv "$f.new" "$f"

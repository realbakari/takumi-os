#!/usr/bin/env bash
# Migration: the screens kept from the Core live in ~/.config/niri/takumi/outputs.kdl, which the niri
# config includes. Make the file, and add the include to a config that predates it.
set -euo pipefail
dir="$HOME/.config/niri"
target="$dir/takumi/outputs.kdl"
if [[ ! -f "$target" ]]; then
  mkdir -p "$(dirname "$target")"
  printf '%s\n' '// Your screens, as you kept them in the Core: scale, turn and place. Written whole by' '// takumi display (docs/display.md). Empty until you keep a change.' > "$target"
fi
cfg="$dir/config.kdl"
[[ -f "$cfg" ]] || exit 0
grep -q 'include "takumi/outputs.kdl"' "$cfg" && exit 0
grep -q 'include "takumi/overrides.kdl"' "$cfg" || exit 0
cp "$cfg" "$cfg.bak-$(date +%Y%m%d%H%M%S)"
awk '/^include "takumi\/overrides.kdl"/ { print "include \"takumi/outputs.kdl\"" } { print }' "$cfg" > "$cfg.new" && mv "$cfg.new" "$cfg"

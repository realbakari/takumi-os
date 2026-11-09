#!/usr/bin/env bash
# Migration: the touchpad's state lives in ~/.config/niri/takumi/touchpad.kdl, which the niri config includes
# (takumi switch touchpad, docs/laptop-keys.md). Make the file, and add the include to a config that predates it.
set -euo pipefail
dir="$HOME/.config/niri"; target="$dir/takumi/touchpad.kdl"
if [[ ! -f "$target" ]]; then
  mkdir -p "$(dirname "$target")"
  printf '%s\n' '// The touchpad, as you switched it with its key or from the Core (takumi switch touchpad, docs/laptop-keys.md).' \
    '// Written whole by that command; your own touchpad settings go in overrides.kdl.' > "$target"
fi
cfg="$dir/config.kdl"
[[ -f "$cfg" ]] || exit 0
grep -q 'include "takumi/touchpad.kdl"' "$cfg" && exit 0
grep -q 'include "takumi/defaults.kdl"' "$cfg" || exit 0
cp "$cfg" "$cfg.bak-$(date +%Y%m%d%H%M%S)"
awk '{ print } /^include "takumi\/defaults.kdl"/ { print "include \"takumi/touchpad.kdl\"" }' "$cfg" > "$cfg.new" && mv "$cfg.new" "$cfg"

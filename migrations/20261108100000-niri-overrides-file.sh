#!/usr/bin/env bash
# Migration: make sure every user has the niri overrides file the config includes.
set -euo pipefail
target="$HOME/.config/niri/takumi/overrides.kdl"
[[ -f "$target" ]] && exit 0
mkdir -p "$(dirname "$target")"
printf '// Your niri overrides. Loaded last, wins. Never overwritten by takumi settings reset.\n' > "$target"

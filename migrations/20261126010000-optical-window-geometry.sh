#!/usr/bin/env bash
# Migration: refresh defaults.kdl for concentric 14 px window corners and deeper ambient elevation shadows,
# and re-render the current theme so niri picks up the directional optical focus-ring gradient.
set -euo pipefail

f="$HOME/.config/niri/takumi/defaults.kdl"
src=""
for d in /usr/share/takumi/config/niri/takumi "$(dirname "$(readlink -f "$0")")/../config/niri/takumi"; do
  [[ -f "$d/defaults.kdl" ]] && { src="$d/defaults.kdl"; break; }
done
if [[ -n "$src" && -f "$f" ]] && ! cmp -s "$src" "$f"; then
  cp "$f" "$f.bak-$(date +%Y%m%d%H%M%S)"
  cp "$src" "$f"
fi

if command -v takumi >/dev/null && [[ -f "$HOME/.local/state/takumi/look/palette.toml" ]]; then
  takumi phase tick --force >/dev/null 2>&1 || true
fi

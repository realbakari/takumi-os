#!/usr/bin/env bash
# Migration: apply Takumi whole-OS cohesion updates (spacious foot padding, bespoke themed squircle app icons,
# refined GTK4/Firefox templates, and clean ':close' GTK headerbars).
set -euo pipefail

foot_cfg="$HOME/.config/foot/foot.ini"
if [[ -f "$foot_cfg" ]] && grep -qx 'pad=14x14' "$foot_cfg"; then
  sed -i.bak 's/^pad=14x14$/pad=18x16 center/' "$foot_cfg" && rm -f "$foot_cfg.bak"
fi

if command -v takumi >/dev/null && [[ -f "$HOME/.config/takumi/theme" ]]; then
  takumi theme apply "$(cat "$HOME/.config/takumi/theme")" >/dev/null 2>&1 || true
fi

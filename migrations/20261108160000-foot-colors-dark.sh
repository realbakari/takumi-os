#!/usr/bin/env bash
# Migration: foot 1.28 reads a theme's colours only under [colors-dark] and only as RRGGBB, so the old
# rendering made every new terminal start with an error. Render the current theme again.
set -euo pipefail
f="$HOME/.local/state/takumi/look/foot-theme.ini"
[[ -f "$f" ]] || exit 0
grep -q '^\[colors-dark\]' "$f" && exit 0
command -v takumi >/dev/null || exit 0
takumi phase tick --force >/dev/null

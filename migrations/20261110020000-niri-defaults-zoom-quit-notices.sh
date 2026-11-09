#!/usr/bin/env bash
# Migration: Takumi's own niri file gains this release's keys and includes: zoom (Super+Alt+=, -, 0 and the
# arrows), force quit (Super+Alt+Escape), going through waiting notices (Super+Alt+Page Up and Page Down),
# brightness one point at a time (Alt with the brightness keys), and
# the two files the Core writes for you, input.kdl (pointer, touchpad, key repeat) and motion.kdl (animations
# off). defaults.kdl is Takumi's (yours is overrides.kdl, and `takumi settings reset` replaces this one anyway),
# so this release's copy replaces it; the old one is kept beside it.
set -euo pipefail
f="$HOME/.config/niri/takumi/defaults.kdl"
src=""
for d in /usr/share/takumi/config/niri/takumi "$(dirname "$(readlink -f "$0")")/../config/niri/takumi"; do
  [[ -f "$d/defaults.kdl" ]] && { src="$d/defaults.kdl"; break; }
done
[[ -n "$src" && -f "$f" ]] || exit 0
cmp -s "$src" "$f" && exit 0
cp "$f" "$f.bak-$(date +%Y%m%d%H%M%S)"
cp "$src" "$f"
echo "defaults.kdl is this release's; the one before is kept beside it"

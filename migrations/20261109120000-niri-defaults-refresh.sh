#!/usr/bin/env bash
# Migration: Takumi's own niri file gains this release's everyday keys: the sound, microphone and media keys,
# the keyboard light and touchpad keys, dictation, marking up a screenshot, the apps you chose for Terminal,
# Files and Browser, and the input method's environment. defaults.kdl is Takumi's (yours is overrides.kdl, and
# `takumi settings reset` replaces this one anyway), so this release's copy replaces it; the old one is kept
# beside it.
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

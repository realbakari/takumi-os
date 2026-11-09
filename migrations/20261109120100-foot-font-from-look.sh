#!/usr/bin/env bash
# Migration: foot's font comes from the look (takumi font, docs/look.md), so Takumi's fixed font line goes, copied
# aside first; it named a font that was never installed, and it came after the look's own line.
set -euo pipefail
f="$HOME/.config/foot/foot.ini"; line='font=JetBrainsMono Nerd Font:size=11'
[[ -f "$f" ]] && grep -qxF "$line" "$f" || exit 0
cp "$f" "$f.bak-$(date +%Y%m%d%H%M%S)"
grep -vxF "$line" "$f" > "$f.new" && mv "$f.new" "$f"
takumi phase tick --force >/dev/null 2>&1 || true

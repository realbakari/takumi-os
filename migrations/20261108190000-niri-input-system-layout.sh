#!/usr/bin/env bash
# Migration: niri takes the keyboard layout from the system (localectl, which the login screen uses too)
# instead of a fixed "us", and a touchpad clicks and scrolls like a Mac's: the lines in Takumi's own
# defaults.kdl, which `takumi settings reset` replaces anyway (docs/the-strip.md).
set -euo pipefail
f="$HOME/.config/niri/takumi/defaults.kdl"
[[ -f "$f" ]] || exit 0
grep -q 'click-method "clickfinger"' "$f" && ! grep -q 'xkb { layout "us"; }' "$f" && exit 0
cp "$f" "$f.bak-$(date +%Y%m%d%H%M%S)"
awk '
  /^[[:space:]]*xkb \{ layout "us"; \}[[:space:]]*$/ { next }
  { print }
  /^[[:space:]]*accel-profile "adaptive"[[:space:]]*$/ && !done {
    print "        click-method \"clickfinger\"   // two fingers press for the right button, three for the middle, as on a Mac"
    print "        scroll-factor 0.5            // libinput'"'"'s own speed runs well ahead of the fingers"
    done = 1
  }' "$f" > "$f.new" && mv "$f.new" "$f"

#!/usr/bin/env bash
# Migration: the first one every home runs, dated before all the others. It copies each setting Takumi
# ships that this home lacks (never one it has), draws the first look and starts the phase timer, so a home
# made before Takumi was installed starts the same way as a new one. See docs/migrations.md.
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
src=""; for d in /usr/share/takumi/config "$here/../config"; do [[ -d "$d" ]] && { src=$d; break; }; done
[[ -n "$src" ]] && rsync -a --ignore-existing "$src/" "$HOME/.config/"
mkdir -p "$HOME/.local/state/takumi"
takumi phase tick --force >/dev/null
systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now takumi-phase.timer 2>/dev/null || true

#!/usr/bin/env bash
# Migration: the scripts Takumi runs when something happens live in ~/.config/takumi/on/, named for what
# happened: theme-change (was hooks/theme-set) and update-ready (was hooks/update-done). Move yours there;
# nothing is overwritten, and hooks/ goes once it holds nothing of yours.
set -euo pipefail
old="$HOME/.config/takumi/hooks" new="$HOME/.config/takumi/on"
[[ -d "$old" ]] || exit 0
mkdir -p "$new"
if [[ -e "$old/theme-set" && ! -e "$new/theme-change" ]]; then mv "$old/theme-set" "$new/theme-change"; fi
if [[ -e "$old/update-done" && ! -e "$new/update-ready" ]]; then mv "$old/update-done" "$new/update-ready"; fi
# The old seed README goes only if it is still word for word what Takumi wrote.
if [[ "$(cat "$old/README.md" 2>/dev/null)" == "# Executable files here run on events: theme-set <name>, update-done <room>." ]]; then rm -f "$old/README.md"; fi
rmdir "$old" 2>/dev/null || true

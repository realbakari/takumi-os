#!/usr/bin/env bash
# Migration: update defaults.kdl with Super+K for the native Core Keys sheet, and wire GtkSourceView 5
# (GNOME Text Editor) and Qt6 (qt6ct) colour templates into existing homes.
set -euo pipefail

# 1. Refresh defaults.kdl (keeping any previous copy beside it).
f="$HOME/.config/niri/takumi/defaults.kdl"
src=""
for d in /usr/share/takumi/config/niri/takumi "$(dirname "$(readlink -f "$0")")/../config/niri/takumi"; do
  [[ -f "$d/defaults.kdl" ]] && { src="$d/defaults.kdl"; break; }
done
if [[ -n "$src" && -f "$f" ]] && ! cmp -s "$src" "$f"; then
  cp "$f" "$f.bak-$(date +%Y%m%d%H%M%S)"
  cp "$src" "$f"
fi

# 2. Wire GtkSourceView 5 style scheme and qt6ct colour scheme links to ~/.local/state/takumi/look.
look="$HOME/.local/state/takumi/look"
mkdir -p "$HOME/.local/share/gtksourceview-5/styles"
ln -sfn "$look/gtksourceview.xml" "$HOME/.local/share/gtksourceview-5/styles/takumi.xml"
command -v gsettings >/dev/null && gsettings set org.gnome.TextEditor style-scheme takumi 2>/dev/null || true

if [[ -d "$HOME/.config/qt6ct" ]] || command -v qt6ct >/dev/null; then
  mkdir -p "$HOME/.config/qt6ct/colors"
  ln -sfn "$look/qt6ct.conf" "$HOME/.config/qt6ct/colors/takumi.conf"
fi

#!/usr/bin/env bash
# Wire rendered theme files for GTK3/GTK4, btop, and Neovim into existing user configs.
set -euo pipefail

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/btop/themes" "$HOME/.config/nvim/plugin"

wire_gtk() {
  local f=$1 line='@import url("../../.local/state/takumi/look/gtk.css");'
  if [[ ! -f "$f" ]]; then
    printf '%s\n' "$line" > "$f"
  elif ! grep -q 'takumi/look/gtk\.css' "$f"; then
    printf '\n%s\n' "$line" >> "$f"
  fi
}
wire_gtk "$HOME/.config/gtk-3.0/gtk.css"
wire_gtk "$HOME/.config/gtk-4.0/gtk.css"

[[ -e "$HOME/.config/btop/themes/takumi.theme" || -L "$HOME/.config/btop/themes/takumi.theme" ]] || \
  ln -sfn "../../../.local/state/takumi/look/btop.theme" "$HOME/.config/btop/themes/takumi.theme"

if [[ ! -f "$HOME/.config/btop/btop.conf" ]]; then
  cat > "$HOME/.config/btop/btop.conf" <<'EOF'
# Takumi btop. Colours come from ~/.local/state/takumi/look/btop.theme.
color_theme = "takumi"
theme_background = False
truecolor = True
EOF
fi

if [[ ! -f "$HOME/.config/nvim/plugin/takumi-theme.lua" ]]; then
  src=""
  for cand in /usr/share/takumi/config/nvim/plugin/takumi-theme.lua "$HOME/.local/share/takumi/config/nvim/plugin/takumi-theme.lua"; do
    [[ -f "$cand" ]] && { src=$cand; break; }
  done
  [[ -n "$src" ]] && cp "$src" "$HOME/.config/nvim/plugin/takumi-theme.lua"
fi


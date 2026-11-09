#!/usr/bin/env bash
# Migration: the drawn look lives in ~/.local/state/takumi/look/ (palette.toml, the app files, the sky
# picture), and your own app-colour templates in ~/.config/takumi/app-colours/. Move your templates there,
# point the app configs that read the look at it (each copied aside first), draw the look again and let the
# old folder go. See docs/phase-themes.md.
set -euo pipefail
stamp=$(date +%Y%m%d%H%M%S)
old="$HOME/.config/takumi/themed" new="$HOME/.config/takumi/app-colours"
if [[ -d "$old" ]]; then
  mkdir -p "$new"
  for t in "$old"/*.tmpl; do
    [[ -f "$t" ]] || continue
    b=$(basename "$t" .tmpl)
    if [[ ! -e "$new/$b" ]]; then mv "$t" "$new/$b"; fi
  done
  rmdir "$old" 2>/dev/null || true
fi
for f in "$HOME/.config/foot/foot.ini" "$HOME/.config/niri/takumi/defaults.kdl" "$HOME/.config/gtk-3.0/gtk.css" \
         "$HOME/.config/gtk-4.0/gtk.css" "$HOME/.config/nvim/plugin/takumi-theme.lua" "$HOME/.config/btop/btop.conf"; do
  [[ -f "$f" ]] && grep -q 'takumi/current/' "$f" || continue
  cp "$f" "$f.bak-$stamp"
  sed 's|takumi/current/|takumi/look/|g' "$f" > "$f.new" && mv "$f.new" "$f"
done
link="$HOME/.config/btop/themes/takumi.theme"
if [[ -L "$link" && "$(readlink "$link")" == *takumi/current/* ]]; then
  ln -sfn ../../../.local/state/takumi/look/btop.theme "$link"
fi
takumi phase tick --force >/dev/null
rm -rf -- "${HOME:?}/.local/state/takumi/current"
# The login screen's copy of your look uses the new names too; the old ones go.
if [[ -d /var/lib/takumi/greeter && -w /var/lib/takumi/greeter ]]; then
  rm -f /var/lib/takumi/greeter/*/theme.toml /var/lib/takumi/greeter/*/background /var/lib/takumi/greeter/background 2>/dev/null || true
fi
exit 0

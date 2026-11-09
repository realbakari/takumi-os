#!/usr/bin/env bash
# Fonts: the interface font, the code font and the text size, and how each reaches the apps. Sourced by
# commands/font/*, commands/theme/render and the Palette's font rows; runs on bash 3.2. See docs/look.md.
#
# What you chose lives in ~/.config/takumi/shell.toml, which the shell watches: font_ui, font_mono and
# font_size (the size the Core's text is drawn at, 13 to begin with; takumi display text writes it too).
# GTK takes the families from GNOME's settings and the size from its text scale; foot and every app that
# asks fontconfig for "sans-serif" or "monospace" (Qt apps, browsers, Electron apps) get them from the
# rendered look: look/foot-theme.ini and look/fontconfig.conf, linked into fontconfig's own folder.

font_shell="$HOME/.config/takumi/shell.toml"
font_look="$HOME/.local/state/takumi/look"
font_conf="$HOME/.config/fontconfig/conf.d/60-takumi-fonts.conf"
font_ui_default="Inter"
font_mono_default="JetBrains Mono"

# font_ui, font_mono: the families in use. font_size: the Core's text size.
font_ui()   { local v=""; [[ -f "$font_shell" ]] && v=$(sed -n 's/^font_ui[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$font_shell" | head -n 1); printf '%s' "${v:-$font_ui_default}"; }
font_mono() { local v=""; [[ -f "$font_shell" ]] && v=$(sed -n 's/^font_mono[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$font_shell" | head -n 1); printf '%s' "${v:-$font_mono_default}"; }
font_size() {
  local v=""
  [[ -f "$font_shell" ]] && v=$(sed -n 's/^font_size[[:space:]]*=[[:space:]]*\([0-9][0-9.]*\).*/\1/p' "$font_shell" | head -n 1)
  printf '%s' "${v:-13}"
}

# font_points <size>: the point size apps take for a text size: 11 at 13, to the nearest half point.
font_points() { awk -v n="$1" 'BEGIN { v = int(n * 11 / 13 * 2 + 0.5) / 2; if (v == int(v)) printf "%d", v; else printf "%.1f", v }'; }

# font_safe <family>: a name the look's files can carry as it is: letters, digits, spaces and . _ + -
font_safe() { local re='^[A-Za-z0-9][A-Za-z0-9 ._+-]*$'; [[ "$1" =~ $re ]]; }

# font_save <font_ui|font_mono> <family>: one line of shell.toml; the others are kept.
font_save() {
  mkdir -p "${font_shell%/*}"; [[ -f "$font_shell" ]] || : > "$font_shell"
  awk -v k="$1" -v line="$1 = \"$2\"" '
    $0 ~ "^" k "[[:space:]]*=" { if (!seen) print line; seen = 1; next }
    { print }
    END { if (!seen) print line }' "$font_shell" > "$font_shell.tmp"
  mv "$font_shell.tmp" "$font_shell"
}

# font_families: the installed families that set English text, one per line, by name:
#   family <tab> styles <tab> mono (yes or no)
# One fc-list call; a family is monospaced when any of its files says so.
font_families() {
  command -v fc-list >/dev/null || return 0
  fc-list :lang=en --format '%{family[0]}\t%{spacing}\n' 2>/dev/null | awk -F '\t' '
    { f = $1; gsub(/\\/, "", f); if (f == "") next; n[f]++
      if ($2 == "100" || $2 == "90" || $2 == "110" || $2 == "mono" || $2 == "dual" || $2 == "charcell") m[f] = 1 }
    END { for (f in n) printf "%s\t%d\t%s\n", f, n[f], (f in m ? "yes" : "no") }' | sort -f
}

# font_find <name>: the installed family a name means, ignoring case and spaces ("jetbrainsmono"), or nothing.
font_find() {
  local want
  want=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
  font_families | awk -F '\t' -v w="$want" '{ k = tolower($1); gsub(/ /, "", k); if (k == w) { print $1; exit } }'
}

# The families Takumi can get for you, all from Arch's own repositories:
#   name | package | repository | ui, mono or symbols | the family to choose | what it is
font_catalog() {
  cat <<'FONTS'
Inter|inter-font|extra|ui|Inter|the interface face Takumi starts with
JetBrains Mono|ttf-jetbrains-mono|extra|mono|JetBrains Mono|the code face Takumi starts with
Noto|noto-fonts|extra|ui|Noto Sans|one family for every script: Noto Sans, Noto Serif and Noto Sans Mono
IBM Plex|ttf-ibm-plex|extra|ui|IBM Plex Sans|IBM's family: Plex Sans, Plex Serif and Plex Mono
Fira Sans|ttf-fira-sans|extra|ui|Fira Sans|Mozilla's interface face
Fira Mono|ttf-fira-mono|extra|mono|Fira Mono|Fira for code
Fira Code|ttf-fira-code|extra|mono|Fira Code|Fira Mono with ligatures for code
Source Sans|adobe-source-sans-fonts|extra|ui|Source Sans 3|Adobe's interface face
Source Serif|adobe-source-serif-fonts|extra|ui|Source Serif 4|Adobe's serif for reading
Source Code Pro|adobe-source-code-pro-fonts|extra|mono|Source Code Pro|Adobe's face for code
Cascadia Code|ttf-cascadia-code|extra|mono|Cascadia Code|Microsoft's terminal face, with Cascadia Mono beside it
Hack|ttf-hack|extra|mono|Hack|a face for code grown from DejaVu Sans Mono
Roboto|ttf-roboto|extra|ui|Roboto|Android's interface face
Roboto Mono|ttf-roboto-mono|extra|mono|Roboto Mono|Roboto for code
Ubuntu|ttf-ubuntu-font-family|extra|ui|Ubuntu|Ubuntu's face, with Ubuntu Mono
DejaVu|ttf-dejavu|extra|ui|DejaVu Sans|the long-serving family with wide coverage, DejaVu Sans Mono among it
Open Sans|ttf-opensans|extra|ui|Open Sans|a plain, friendly face for screens
Iosevka|ttc-iosevka|extra|mono|Iosevka|a narrow face for code
JetBrains Mono Nerd Font|ttf-jetbrains-mono-nerd|extra|mono|JetBrainsMono Nerd Font|JetBrains Mono with Nerd Fonts' symbols
IBM Plex Mono Nerd Font|ttf-ibmplex-mono-nerd|extra|mono|BlexMono Nerd Font|IBM Plex Mono with Nerd Fonts' symbols
Fira Code Nerd Font|ttf-firacode-nerd|extra|mono|FiraCode Nerd Font|Fira Code with Nerd Fonts' symbols
Source Code Pro Nerd Font|ttf-sourcecodepro-nerd|extra|mono|SauceCodePro Nerd Font|Source Code Pro with Nerd Fonts' symbols
Cascadia Code Nerd Font|ttf-cascadia-code-nerd|extra|mono|CaskaydiaCove Nerd Font|Cascadia Code with Nerd Fonts' symbols
Cascadia Mono Nerd Font|ttf-cascadia-mono-nerd|extra|mono|CaskaydiaMono Nerd Font|Cascadia Mono with Nerd Fonts' symbols
Hack Nerd Font|ttf-hack-nerd|extra|mono|Hack Nerd Font|Hack with Nerd Fonts' symbols
Nerd Font symbols|ttf-nerd-fonts-symbols|extra|symbols|Symbols Nerd Font|only the symbols, for prompts and tools that draw them
FONTS
}

# font_catalog_find <name>: the catalog line a name means: the name, the family to choose or the package,
# ignoring case and spaces; else the one line whose name holds it. Returns 2 when several lines hold it.
font_catalog_find() {
  local want hit
  want=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
  [[ -n "$want" ]] || return 1
  hit=$(font_catalog | awk -F '|' -v w="$want" '
    BEGIN { split("1 2 5", field, " ") }
    { for (j = 1; j <= 3; j++) { k = tolower($(field[j])); gsub(/ /, "", k); if (k == w) { print; exit } } }')
  [[ -n "$hit" ]] && { printf '%s\n' "$hit"; return 0; }
  hit=$(font_catalog | awk -F '|' -v w="$want" '{ k = tolower($1); gsub(/ /, "", k); if (index(k, w)) print }')
  [[ -n "$hit" ]] || return 1
  [[ "$hit" == *$'\n'* ]] && { printf '%s\n' "$hit"; return 2; }
  printf '%s\n' "$hit"
}

# font_have_package <package>: true when it is installed.
font_have_package() { pacman -Q "$1" >/dev/null 2>&1; }

# font_apply: your fonts everywhere. The look is drawn again (foot's font line, the fontconfig aliases),
# the aliases are linked where fontconfig reads a person's own settings, and GNOME's settings carry the
# families to GTK. The shell reads shell.toml by itself. GTK's size stays 11 points: the text scale that
# takumi display text sets makes it bigger or smaller with the Core.
font_apply() {
  local ui mono theme
  ui=$(font_ui); mono=$(font_mono)
  theme=$(cat "$HOME/.config/takumi/theme" 2>/dev/null || true)
  takumi theme render "${theme:-ion}" "$(takumi phase current)" >/dev/null
  mkdir -p "${font_conf%/*}"
  ln -sfn "$font_look/fontconfig.conf" "$font_conf"
  if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface font-name "$ui 11" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface document-font-name "$ui 11" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface monospace-font-name "$mono 11" 2>/dev/null || true
  fi
}

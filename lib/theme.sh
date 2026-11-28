#!/usr/bin/env bash
# Themes: finding them, merging a phase, checking that text stays readable, making a theme from a picture,
# folder icons in the accent, and the browsers in the theme's colours. Sourced by commands/theme/* and
# commands/font/*; runs on bash 3.2 with any awk. See docs/phase-themes.md and docs/look.md.

theme_lib_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
theme_user_dir="$HOME/.config/takumi/themes"
theme_look="$HOME/.local/state/takumi/look"
theme_keys="accent background surface foreground muted red yellow green cyan blue magenta"

# theme_dirs: where themes live, the first that has a name wins: yours, Takumi's, then a checkout's.
theme_dirs() { printf '%s\n' "$theme_user_dir" /usr/share/takumi/themes "$theme_lib_dir/../themes"; }

# theme_find <name>: the theme's folder, or nothing. A name is a folder's name, never a path.
theme_find() {
  local d re='^[A-Za-z0-9][A-Za-z0-9._-]*$'
  [[ "$1" =~ $re ]] || return 1
  while IFS= read -r d; do
    [[ -f "$d/$1/theme.toml" ]] && { (cd "$d/$1" && pwd); return 0; }
  done < <(theme_dirs)
  return 1
}

# theme_current: the theme you chose.
theme_current() { local n; n=$(cat "$HOME/.config/takumi/theme" 2>/dev/null || true); printf '%s' "${n:-ion}"; }

# theme_meta <theme.toml> <key>: a [meta] value, quoted or bare.
theme_meta() {
  awk -v want="$2" '
    /^\[/ { sect = $0; gsub(/[][ ]/, "", sect); next }
    sect == "meta" && /^[a-z_]+[ \t]*=/ {
      k = $1; sub(/=.*$/, "", k); if (k != want) next
      v = $0; sub(/^[^=]*=[ \t]*/, "", v)
      if (v ~ /^"/) { sub(/^"/, "", v); sub(/".*$/, "", v) } else { sub(/[ \t]*#.*$/, "", v); sub(/[ \t]+$/, "", v) }
      print v; exit
    }' "$1"
}

# theme_merged <theme.toml> <phase>: key=value lines, the [palette] keys with [phase.<phase>] over them,
# then mode, name, phase and glass (true only when [meta] says glass = true).
theme_merged() {
  awk -v phase="$2" '
    /^\[/ { sect = $0; gsub(/[][ ]/, "", sect); next }
    /^[a-z_]+[ \t]*=/ {
      key = $1; sub(/=.*$/, "", key); val = $0; sub(/^[^=]*=[ \t]*/, "", val)
      if (val ~ /^"/) { sub(/^"/, "", val); sub(/".*$/, "", val) } else { sub(/[ \t]*#.*$/, "", val); sub(/[ \t]+$/, "", val) }
      if (sect == "palette") pal[key] = val
      else if (sect == "phase." phase) ph[key] = val
      else if (sect == "meta") meta[key] = val
    }
    END {
      for (k in pal) printf "%s=%s\n", k, (k in ph ? ph[k] : pal[k])
      printf "mode=%s\nname=%s\nphase=%s\nglass=%s\n", meta["mode"], meta["name"], phase, (meta["glass"] == "true" ? "true" : "false")
    }' "$1"
}

# Colour arithmetic for awk, prepended to the programs below: sRGB in, WCAG 2 contrast out.
#   rgb(h) sets R G B (0..1)   lum(h) relative luminance   ratio(a, b) contrast, 1 to 21
#   tohsl(h) sets H (degrees) S L   hsl(h, s, l) back to #rrggbb
#   fit(h, s, l, ref, target, dir): the colour of hue h and saturation s whose lightness, moved from l
#     lighter (dir 1) or darker (dir -1), first reaches the target contrast against ref.
theme_awk='
function hexd(c) { return index("0123456789abcdef", tolower(c)) - 1 }
function hex2(s, i) { return hexd(substr(s, i, 1)) * 16 + hexd(substr(s, i + 1, 1)) }
function rgb(h) { sub(/^#/, "", h); R = hex2(h, 1) / 255; G = hex2(h, 3) / 255; B = hex2(h, 5) / 255 }
function lin(c) { return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
function lum(h) { rgb(h); return 0.2126 * lin(R) + 0.7152 * lin(G) + 0.0722 * lin(B) }
function ratio(a, b,   x, y, t) { x = lum(a); y = lum(b); if (x < y) { t = x; x = y; y = t }; return (x + 0.05) / (y + 0.05) }
function cl(v) { return v < 0 ? 0 : (v > 1 ? 1 : v) }
function hex(r, g, b) { return sprintf("#%02x%02x%02x", int(cl(r) * 255 + 0.5), int(cl(g) * 255 + 0.5), int(cl(b) * 255 + 0.5)) }
function min(a, b) { return a < b ? a : b }
function max(a, b) { return a > b ? a : b }
function clamp(v, a, b) { return v < a ? a : (v > b ? b : v) }
function abs(v) { return v < 0 ? -v : v }
function tohsl(h,   mx, mn, d) {
  rgb(h); mx = max(R, max(G, B)); mn = min(R, min(G, B)); L = (mx + mn) / 2; d = mx - mn
  if (d == 0) { H = 0; S = 0; return }
  S = L > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
  if (mx == R) H = (G - B) / d + (G < B ? 6 : 0); else if (mx == G) H = (B - R) / d + 2; else H = (R - G) / d + 4
  H = H * 60
}
function hue2(p, q, t) { if (t < 0) t += 1; if (t > 1) t -= 1; if (t < 1 / 6) return p + (q - p) * 6 * t; if (t < 1 / 2) return q; if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6; return p }
function hsl(h, s, l,   q, p) {
  while (h < 0) h += 360; while (h >= 360) h -= 360; h = h / 360; s = cl(s); l = cl(l)
  if (s == 0) return hex(l, l, l)
  q = l < 0.5 ? l * (1 + s) : l + s - l * s; p = 2 * l - q
  return hex(hue2(p, q, h + 1 / 3), hue2(p, q, h), hue2(p, q, h - 1 / 3))
}
function fit(h, s, l, ref, target, dir,   c, i) {
  for (i = 0; i < 500; i++) { c = hsl(h, s, l); if (ratio(c, ref) >= target) return c; l = cl(l + dir * 0.002) }
  return c
}
function refit(c, ref, target, dir) { tohsl(c); return ratio(c, ref) >= target ? c : fit(H, S, L, ref, target, dir) }
function hdist(a, b,   d) { d = abs(a - b); while (d >= 360) d -= 360; return d > 180 ? 360 - d : d }
function hmix(a, b, t,   d) { d = b - a; while (d > 180) d -= 360; while (d < -180) d += 360; a += d * t; while (a < 0) a += 360; while (a >= 360) a -= 360; return a }
function mixhex(a, b, t,   r1, g1, b1) { rgb(a); r1 = R; g1 = G; b1 = B; rgb(b); return hex(r1 * t + R * (1 - t), g1 * t + G * (1 - t), b1 * t + B * (1 - t)) }
'

# theme_contrast <colour> <colour>: the contrast between two #rrggbb colours, as "4.52".
theme_contrast() { awk -v a="$1" -v b="$2" "$theme_awk"'BEGIN { printf "%.2f\n", ratio(a, b) }'; }

# The two rules every theme Takumi makes keeps, in every phase: body text at 4.5:1 or better against the
# background (and the surface), the accent at 3:1 or better against the surface and the background.
theme_rule_text=4.5
theme_rule_accent=3

# theme_check <theme.toml>: one line per phase, "phase text accent quiet ok|low": the contrast of the
# text on the background (the lower of background and surface), the accent on the surface (the lower of
# surface and background), quiet text on the background. Returns 1 when a phase breaks a rule.
theme_check() {
  local p merged status=0 line
  for p in dawn day dusk night; do
    merged=$(theme_merged "$1" "$p")
    line=$(awk -v text="$theme_rule_text" -v acc="$theme_rule_accent" -v phase="$p" "$theme_awk"'
      { split($0, kv, "="); c[kv[1]] = kv[2] }
      END {
        t = min(ratio(c["foreground"], c["background"]), ratio(c["foreground"], c["surface"]))
        a = min(ratio(c["accent"], c["surface"]), ratio(c["accent"], c["background"]))
        q = ratio(c["muted"], c["background"])
        printf "%s %.2f %.2f %.2f %s\n", phase, t, a, q, (t >= text && a >= acc ? "ok" : "low")
      }' <<< "$merged")
    printf '%s\n' "$line"
    [[ "$line" == *" ok" ]] || status=1
  done
  return $status
}

# theme_histogram <picture>: the picture's eight main colours, "count #rrggbb" per line, most first, from
# ImageMagick's quantiser at 64 by 64 pixels. jpeg:size lets a large photo be read at a fraction of its size.
theme_histogram() {
  local out
  out=$(magick -define jpeg:size=256x256 "$1[0]" -alpha off -resize 64x64 -colors 8 -depth 8 -format %c histogram:info:- 2>/dev/null) || return 1
  awk '{
    n = $1; sub(/:$/, "", n)
    if (match($0, /#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/) && n + 0 > 0)
      printf "%d %s\n", n, tolower(substr($0, RSTART, 7))
  }' <<< "$out" | sort -rn
}

# theme_derive [dark|light|auto]: a whole palette and its phases from "count #rrggbb" lines on stdin.
# Prints mode=<dark|light> and <palette|dawn|dusk|night>.<key>=#rrggbb lines.
#
# Light or dark follows how light the picture is overall. The background takes the hue of the picture's
# largest area on that side (dark areas for a dark theme), calmed and pushed very dark or very light; the
# surface is a step from it. The accent is the picture's most vivid colour (a quiet steel blue when the
# picture has none). The six named colours keep their meaning, each pulled halfway to a picture colour
# near it. Every colour is then moved, lighter or darker only, until it reads: text at 7:1, quiet text at
# 3:1, the accent at 3:1 against the surface, named colours at 4.5:1. Dawn warms the accent and the
# background, dusk warms the accent further, night sinks the background, softens the text and quiets
# the accent, blues most; each is held to the same contrast.
theme_derive() {
  awk -v want="${1:-auto}" "$theme_awk"'
    NF >= 2 && $2 ~ /^#/ { k++; cnt[k] = $1; col[k] = $2; total += $1 }
    END {
      if (k == 0 || total <= 0) { print "error=no colours"; exit 1 }
      for (i = 1; i <= k; i++) {
        w[i] = cnt[i] / total; y = lum(col[i])
        ls = y > 0.008856 ? 116 * y ^ (1 / 3) - 16 : 903.3 * y
        light += w[i] * ls
        tohsl(col[i]); h[i] = H; s[i] = S; l[i] = L
      }
      mode = (want == "dark" || want == "light") ? want : (light > 58 ? "light" : "dark")
      dir = mode == "dark" ? 1 : -1
      dark = mode == "dark"

      # The background: the largest area on the side of the mode.
      best = -1
      for (i = 1; i <= k; i++) { sc = w[i] * (dark ? 1.15 - l[i] : l[i] + 0.15); if (sc > best) { best = sc; bi = i } }
      bh = h[bi]; bs = s[bi]
      sbg = bs < 0.08 ? bs : (dark ? min(0.28, bs * 0.5) : min(0.22, bs * 0.4))
      lbg = dark ? clamp(0.055 + l[bi] * 0.06, 0.055, 0.11) : clamp(0.93 + l[bi] * 0.04, 0.93, 0.97)
      lsf = dark ? lbg + 0.045 : lbg - 0.05
      bg = hsl(bh, sbg, lbg); sf = hsl(bh, sbg, lsf)
      fg = fit(bh, min(0.12, sbg), dark ? 0.88 : 0.14, bg, 7, dir); fg = refit(fg, sf, 7, dir)
      muted = refit(mixhex(fg, bg, 0.45), bg, 3.2, dir)

      # The accent: the most vivid colour, away from the background hue when it can be.
      ai = 0; best = -1
      for (i = 1; i <= k; i++) {
        if (s[i] < 0.22 || l[i] < 0.12 || l[i] > 0.92) continue
        sc = s[i] * (1 - 0.8 * abs(l[i] - 0.55)) * (0.4 + sqrt(w[i])) * (bs >= 0.08 && hdist(h[i], bh) < 25 ? 0.75 : 1)
        if (sc > best) { best = sc; ai = i }
      }
      if (ai) { ah = h[ai]; as = clamp(s[ai], 0.45, 0.9); al = dark ? clamp(l[ai], 0.6, 0.75) : clamp(l[ai], 0.32, 0.45) }
      else { ah = 210; as = 0.28; al = dark ? 0.66 : 0.4 }
      acc = fit(ah, as, al, sf, 3.1, dir)

      split("red yellow green cyan blue magenta", nn, " "); split("355 45 125 185 220 295", nh, " ")
      for (j = 1; j <= 6; j++) {
        hh = nh[j]; bd = 26; fi = 0
        for (i = 1; i <= k; i++) if (s[i] >= 0.3 && l[i] > 0.15 && l[i] < 0.9 && hdist(h[i], nh[j]) < bd) { bd = hdist(h[i], nh[j]); fi = i }
        if (fi) hh = hmix(hh, h[fi], 0.5)
        named[nn[j]] = fit(hh, dark ? 0.7 : 0.65, dark ? 0.68 : 0.42, bg, 4.5, dir)
      }
      print "mode=" mode
      printf "palette.accent=%s\npalette.background=%s\npalette.surface=%s\npalette.foreground=%s\npalette.muted=%s\n", acc, bg, sf, fg, muted
      for (j = 1; j <= 6; j++) printf "palette.%s=%s\n", nn[j], named[nn[j]]

      # Dawn and dusk warm the accent from the picture'"'"'s own warm colour (red to yellow) when it has one,
      # else from peach and coral; a hue is never swung from blue to orange, which would pass through green.
      wi = 0; best = -1
      for (i = 1; i <= k; i++) if (s[i] >= 0.25 && l[i] > 0.15 && l[i] < 0.9 && (h[i] <= 60 || h[i] >= 330)) { sc = s[i] * (0.3 + sqrt(w[i])); if (sc > best) { best = sc; wi = i } }
      dawnh = wi ? hmix(h[wi], 30, 0.3) : 28; duskh = wi ? hmix(h[wi], 10, 0.3) : 12; ws = clamp(max(as, 0.6), 0.6, 0.9)

      # Dawn: the background a touch warmer and softer, a quarter of the way to a warm colour as light as it.
      dl = dark ? lbg + 0.012 : lbg - 0.01; dsl = dark ? lsf + 0.012 : lsf - 0.01
      dbg = mixhex(hsl(30, 0.45, dl), hsl(bh, sbg, dl), 0.25); dsf = mixhex(hsl(30, 0.45, dsl), hsl(bh, sbg, dsl), 0.25)
      dfg = refit(refit(fg, dbg, 7, dir), dsf, 7, dir)
      printf "dawn.accent=%s\ndawn.background=%s\ndawn.surface=%s\n", fit(dawnh, ws, al, dsf, 3.1, dir), dbg, dsf
      if (dfg != fg) printf "dawn.foreground=%s\n", dfg
      m = refit(muted, dbg, 3.2, dir); if (m != muted) printf "dawn.muted=%s\n", m

      # Dusk: the accent warmer still.
      printf "dusk.accent=%s\n", fit(duskh, ws, al, sf, 3.1, dir)

      # Night: the background sinks, the text softens, the accent quiets and the blues drop.
      nl = dark ? max(0.03, lbg * 0.65) : lbg - 0.045
      nbg = hsl(bh, sbg, nl); nsf = hsl(bh, sbg, dark ? nl + 0.04 : nl - 0.05)
      tohsl(fg); nfg = refit(refit(hsl(H, S, dark ? L - 0.08 : L + 0.05), nbg, 7, dir), nsf, 7, dir)
      nah = (ah >= 170 && ah <= 260) ? hmix(ah, 175, 0.25) : ah
      printf "night.accent=%s\nnight.background=%s\nnight.surface=%s\nnight.foreground=%s\n", fit(nah, as * 0.8, dark ? al - 0.06 : al + 0.04, nsf, 3.1, dir), nbg, nsf, nfg
      m = refit(muted, nbg, 3.2, dir); if (m != muted) printf "night.muted=%s\n", m
      for (j = 1; j <= 6; j++) { c = refit(named[nn[j]], nbg, 4.5, dir); if (c != named[nn[j]]) printf "night.%s=%s\n", nn[j], c }
    }'
}

# theme_toml <name> <title> <about> <glass true|false>: a theme.toml from theme_derive's lines on stdin.
theme_toml() {
  awk -v name="$1" -v title="$2" -v about="$3" -v glass="$4" -v keys="$theme_keys" '
    /^mode=/ { mode = substr($0, 6); next }
    /^[a-z]+\.[a-z]+=#/ { i = index($0, "="); val[substr($0, 1, i - 1)] = substr($0, i + 1) }
    END {
      n = split(keys, key, " ")
      printf "[meta]\nname = \"%s\"\nmode = \"%s\"\ntitle = \"%s\"\nabout = \"%s\"\n", name, mode, title, about
      printf "glass = %s          # true: the terminal and GTK apps let the sky show through a little\n", glass
      printf "\n[palette]\n"; for (i = 1; i <= n; i++) printf "%-10s = \"%s\"\n", key[i], val["palette." key[i]]
      split("dawn dusk night", ph, " ")
      for (p = 1; p <= 3; p++) {
        printf "\n[phase.%s]\n", ph[p]
        for (i = 1; i <= n; i++) if ((ph[p] "." key[i]) in val) printf "%-10s = \"%s\"\n", key[i], val[ph[p] "." key[i]]
      }
    }'
}

# theme_slug <text>: a theme name: lowercase letters, digits and hyphens.
theme_slug() {
  local s
  s=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9][^a-z0-9]*/-/g; s/^-*//; s/-*$//' | cut -c1-40)
  s=${s%-}; printf '%s' "${s:-picture}"
}

# theme_title_of <text>: words for a person, from a file name: "beach_at-dusk" -> "Beach at dusk".
theme_title_of() {
  local t first
  t=$(printf '%s' "$1" | tr '_' ' ' | tr -d '"\\' | sed 's/--*/ /g; s/  */ /g; s/^ //; s/ $//')
  [[ -n "$t" ]] || t="Picture"
  first=$(printf '%s' "${t:0:1}" | tr '[:lower:]' '[:upper:]')
  printf '%s%s' "$first" "${t:1}"
}

# Folder icons in the theme's colour. Papirus ships its folders in two dozen colours (folder-blue.svg,
# folder-blue-documents.svg, user-blue-home.svg, ...); Takumi points a small icon theme of its own,
# ~/.local/share/icons/Takumi, at the colour nearest the accent and inherits the rest of Papirus. Papirus's
# own files are never touched, so this needs no password.
theme_icons_root="${TAKUMI_ICONS:-/usr/share/icons}"
theme_icon_dir="$HOME/.local/share/icons/Takumi"
# Papirus's folder colours, by the colour of the folder's front.
theme_papirus_colours="blue:#5294e2 bluegrey:#607d8b brown:#ae8e6c carmine:#a30002 cyan:#00bcd4 darkcyan:#45abb7
deeporange:#eb6637 green:#87b158 grey:#8e8e8e indigo:#5c6bc0 magenta:#ca71df nordic:#81a1c1 orange:#ee923a
palebrown:#d1bfae paleorange:#eeca8f pink:#f06292 red:#e25252 teal:#16a085 violet:#7e57c2 yellow:#f9bd30
black:#4f4f4f white:#e4e4e4"

# theme_folder_colour <accent>: the Papirus folder colour nearest the accent, among those installed.
theme_folder_colour() {
  local have="" c
  for c in $theme_papirus_colours; do
    [[ -e "$theme_icons_root/Papirus/48x48/places/folder-${c%%:*}.svg" ]] && have+="$c "
  done
  [[ -n "$have" ]] || return 1
  awk -v a="$1" -v list="$have" "$theme_awk"'BEGIN {
    rgb(a); ar = R * 255; ag = G * 255; ab = B * 255; n = split(list, c, " "); best = 1e9
    for (i = 1; i <= n; i++) {
      split(c[i], p, ":"); rgb(p[2]); r = R * 255; g = G * 255; b = B * 255; m = (ar + r) / 2
      d = (2 + m / 256) * (ar - r) ^ 2 + 4 * (ag - g) ^ 2 + (2 + (255 - m) / 256) * (ab - b) ^ 2
      if (d < best) { best = d; name = p[1] }
    }
    print name
  }'
}

# theme_folders <accent> <dark|light> [surface] [background] [foreground]: build the Takumi icon theme with
# accent-matched Papirus folders AND bespoke Takumi squircle SVG icons for core bundled apps (Terminal,
# Monitor, Files, Text Editor, Image Viewer, Document Viewer, Disk Usage, Celluloid). Nothing is rewritten
# when the stamp matches. Returns 1 without Papirus.
theme_app_svg() {  # <out.svg> <surface> <bg> <accent> <fg> <light:0|1> <glyph-path-svg>
  local out=$1 sf=$2 bg=$3 ac=$4 fg=$5 light=$6 glyph=$7
  local rim_op="0.16" spec_op="0.28"
  [[ "$light" == 1 ]] && rim_op="0.14" spec_op="0.55"
  cat > "$out" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="$sf"/>
      <stop offset="1" stop-color="$bg"/>
    </linearGradient>
    <linearGradient id="glow" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="$ac" stop-opacity="0.22"/>
      <stop offset="0.55" stop-color="$ac" stop-opacity="0.04"/>
      <stop offset="1" stop-color="$ac" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="top" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="$fg" stop-opacity="0"/>
      <stop offset="0.5" stop-color="$fg" stop-opacity="$spec_op"/>
      <stop offset="1" stop-color="$fg" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect x="4" y="4" width="56" height="56" rx="15" fill="url(#bg)"/>
  <rect x="4" y="4" width="56" height="56" rx="15" fill="url(#glow)"/>
  <rect x="4.5" y="4.5" width="55" height="55" rx="14.5" fill="none" stroke="$fg" stroke-opacity="$rim_op" stroke-width="1"/>
  <line x1="18" y1="5" x2="46" y2="5" stroke="url(#top)" stroke-width="1"/>
  <g transform="translate(14 14) scale(1.5)" fill="none" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5">
    $glyph
  </g>
</svg>
SVG
}
theme_folders() {
  local colour inherit stamp new d size f base found dirs="" sections=""
  local accent=$1 mode=$2 sf=${3:-} bg=${4:-} fg=${5:-} light=0
  [[ "$mode" == light ]] && light=1
  [[ -n "$sf" ]] || sf=$([[ "$light" == 1 ]] && echo "#ebe4da" || echo "#151c26")
  [[ -n "$bg" ]] || bg=$([[ "$light" == 1 ]] && echo "#f6f1ea" || echo "#0b0f14")
  [[ -n "$fg" ]] || fg=$([[ "$light" == 1 ]] && echo "#26201c" || echo "#d9e2ec")
  colour=$(theme_folder_colour "$accent") || return 1
  inherit=Papirus-Dark; [[ "$mode" == light ]] && inherit=Papirus-Light
  stamp="$colour $inherit $accent $sf $bg $fg v4"
  if [[ "$(cat "$theme_icon_dir/.takumi" 2>/dev/null)" == "$stamp" ]]; then printf '%s\n' "$colour"; return 0; fi
  mkdir -p "$(dirname "$theme_icon_dir")"
  new="$theme_icon_dir.new"; rm -rf "$new"; mkdir -p "$new"
  for d in "$theme_icons_root/Papirus"/*x*/places; do
    size=${d%/places}; size=${size##*/}
    [[ "$size" =~ ^[0-9]+x[0-9]+$ ]] || continue
    found=no
    for f in "$d/folder-$colour.svg" "$d/folder-$colour-"*.svg "$d/user-$colour-"*.svg; do
      [[ -e "$f" ]] || continue
      base=${f##*/}
      mkdir -p "$new/$size/places"; ln -sfn "$f" "$new/$size/places/${base/-$colour/}"; found=yes
    done
    [[ $found == yes ]] || continue
    dirs+="${dirs:+,}$size/places"
    sections+=$(printf '\n\n[%s/places]\nContext=Places\nSize=%s\nType=Fixed' "$size" "${size%%x*}")
  done
  [[ -n "$dirs" ]] || { rm -rf "$new"; return 1; }
  # Takumi's squircle app icons for the bundled utilities, so All apps speaks one design language. Each
  # glyph is a shape from Hugeicons' free Stroke Rounded set (MIT: shell/Look/Icons.LICENSE.md), in the accent.
  mkdir -p "$new/scalable/apps"
  theme_app_svg "$new/scalable/apps/foot.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<path d='M7.5 7.5L8.72654 8.55719C9.24218 9.00163 9.5 9.22386 9.5 9.5C9.5 9.77614 9.24218 9.99836 8.72654 10.4428L7.5 11.5 M11.5 12.5H15.5 M12 21C15.7497 21 17.6246 21 18.9389 20.0451C19.3634 19.7367 19.7367 19.3634 20.0451 18.9389C21 17.6246 21 15.7497 21 12C21 8.25027 21 6.3754 20.0451 5.06107C19.7367 4.6366 19.3634 4.26331 18.9389 3.95491C17.6246 3 15.7497 3 12 3C8.25027 3 6.3754 3 5.06107 3.95491C4.6366 4.26331 4.26331 4.6366 3.95491 5.06107C3 6.3754 3 8.25027 3 12C3 15.7497 3 17.6246 3.95491 18.9389C4.26331 19.3634 4.6366 19.7367 5.06107 20.0451C6.3754 21 8.25027 21 12 21Z' stroke='$accent'/>"
  ln -sfn foot.svg "$new/scalable/apps/utilities-terminal.svg"
  theme_app_svg "$new/scalable/apps/btop.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<path d='M12 21C7.75736 21 5.63604 21 4.31802 19.682C3 18.364 3 16.2426 3 12C3 7.75736 3 5.63604 4.31802 4.31802C5.63604 3 7.75736 3 12 3C16.2426 3 18.364 3 19.682 4.31802C21 5.63604 21 7.75736 21 12C21 16.2426 21 18.364 19.682 19.682C18.364 21 16.2426 21 12 21Z M7 14L9 12C9.40894 11.5911 9.61341 11.3866 9.83398 11.2773C10.2536 11.0693 10.7464 11.0693 11.166 11.2773C11.3866 11.3866 11.5911 11.5911 12 12L12 12C12.4089 12.4089 12.6134 12.6134 12.834 12.7227C13.2536 12.9307 13.7464 12.9307 14.166 12.7227C14.3866 12.6134 14.5911 12.4089 15 12L17 10' stroke='$accent'/>"
  ln -sfn btop.svg "$new/scalable/apps/utilities-system-monitor.svg"
  theme_app_svg "$new/scalable/apps/org.gnome.Nautilus.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<path d='M13.6656 6.49446H16C18.8284 6.49446 20.2426 6.49446 21.1213 7.37314C22 8.25182 22 9.66603 22 12.4945V14.5C22 17.3284 22 18.7426 21.1213 19.6213C20.2426 20.5 18.8284 20.5 16 20.5H8C5.17157 20.5 3.75736 20.5 2.87868 19.6213C2 18.7426 2 17.3284 2 14.5V8.99183C2 6.65409 2 5.48521 2.61604 4.67881C2.7778 4.46706 2.96706 4.2778 3.17881 4.11604C3.98521 3.5 5.15409 3.5 7.49183 3.5C8.16633 3.5 8.50358 3.5 8.81392 3.60442C8.8976 3.63257 8.97932 3.66623 9.05854 3.70518C9.35239 3.84965 9.59179 4.08719 10.0706 4.56227L10.8483 5.33389C11.4254 5.9066 11.714 6.19295 12.08 6.3437C12.446 6.49446 12.8525 6.49446 13.6656 6.49446Z' stroke='$accent'/>"
  ln -sfn org.gnome.Nautilus.svg "$new/scalable/apps/system-file-manager.svg"
  theme_app_svg "$new/scalable/apps/org.gnome.TextEditor.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<path d='M15.5 2V5M6.5 2V5M11 2V5 M19 12V10.5C19 7.20017 19 5.55025 17.9749 4.52512C16.9497 3.5 15.2998 3.5 12 3.5H10C6.70017 3.5 5.05025 3.5 4.02513 4.52513C3 5.55025 3 7.20017 3 10.5V15C3 18.2998 3 19.9497 4.02513 20.9749C5.05025 22 6.70017 22 10 22H11 M7 15H11M7 11H15 M15.7367 21.6527L14 22L14.3473 20.2633C14.4179 19.9106 14.5913 19.5866 14.8456 19.3323L18.9111 15.2668C19.2668 14.9111 19.8437 14.9111 20.1995 15.2668L20.7332 15.8005C21.0889 16.1563 21.0889 16.7332 20.7332 17.0889L16.6677 21.1544C16.4134 21.4087 16.0894 21.5821 15.7367 21.6527Z' stroke='$accent'/>"
  ln -sfn org.gnome.TextEditor.svg "$new/scalable/apps/accessories-text-editor.svg"
  theme_app_svg "$new/scalable/apps/org.gnome.Loupe.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<path d='M6 7.5a1.5 1.5 0 1 0 3 0a1.5 1.5 0 1 0 -3 0 M2.5 12C2.5 7.52166 2.5 5.28249 3.89124 3.89124C5.28249 2.5 7.52166 2.5 12 2.5C16.4783 2.5 18.7175 2.5 20.1088 3.89124C21.5 5.28249 21.5 7.52166 21.5 12C21.5 16.4783 21.5 18.7175 20.1088 20.1088C18.7175 21.5 16.4783 21.5 12 21.5C7.52166 21.5 5.28249 21.5 3.89124 20.1088C2.5 18.7175 2.5 16.4783 2.5 12Z M5 21C9.37246 15.775 14.2741 8.88406 21.4975 13.5424' stroke='$accent'/>"
  ln -sfn org.gnome.Loupe.svg "$new/scalable/apps/loupe.svg"
  theme_app_svg "$new/scalable/apps/org.gnome.Evince.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<path d='M20 13V10.6569C20 9.83935 20 9.4306 19.8478 9.06306C19.6955 8.69552 19.4065 8.40649 18.8284 7.82843L14.0919 3.09188C13.593 2.593 13.3436 2.34355 13.0345 2.19575C12.9702 2.165 12.9044 2.13772 12.8372 2.11401C12.5141 2 12.1614 2 11.4558 2C8.21082 2 6.58831 2 5.48933 2.88607C5.26731 3.06508 5.06508 3.26731 4.88607 3.48933C4 4.58831 4 6.21082 4 9.45584V13M13 2.5V3C13 5.82843 13 7.24264 13.8787 8.12132C14.7574 9 16.1716 9 19 9H19.5 M19.75 16H17.25C16.6977 16 16.25 16.4477 16.25 17V19M16.25 19V22M16.25 19H19.25M4.25 22V19.5M4.25 19.5V16H6C6.9665 16 7.75 16.7835 7.75 17.75C7.75 18.7165 6.9665 19.5 6 19.5H4.25ZM10.25 16H11.75C12.8546 16 13.75 16.8954 13.75 18V20C13.75 21.1046 12.8546 22 11.75 22H10.25V16Z' stroke='$accent'/>"
  ln -sfn org.gnome.Evince.svg "$new/scalable/apps/org.gnome.Papers.svg"
  theme_app_svg "$new/scalable/apps/org.gnome.baobab.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<path d='M8.05653 3.5C2.04493 6.12883 0.629484 14.3347 5.20143 18.8641C9.86407 23.4835 17.9985 21.756 20.5 15.8278 M20.9063 8.60378C20.3946 7.36853 19.6447 6.24615 18.6993 5.30073C17.7538 4.35531 16.6315 3.60536 15.3962 3.0937C14.034 2.52946 13.3529 2.24733 12.4664 2.79477C12.4333 2.81523 12.3766 2.85309 12.345 2.87587C11.5 3.4854 11.5 4.42922 11.5 6.31686V8.42748C11.5 10.3473 11.5 11.3072 12.0964 11.9036C12.6928 12.5 13.6527 12.5 15.5725 12.5H17.6831C19.5708 12.5 20.5146 12.5 21.1241 11.655C21.1469 11.6234 21.1848 11.5667 21.2052 11.5336C21.7527 10.6471 21.4705 9.966 20.9063 8.60378Z' stroke='$accent'/>"
  theme_app_svg "$new/scalable/apps/io.github.celluloid_player.Celluloid.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<path d='M2 12a10 10 0 1 0 20 0a10 10 0 1 0 -20 0 M15.9453 12.3948C15.7686 13.0215 14.9333 13.4644 13.2629 14.3502C11.648 15.2064 10.8406 15.6346 10.1899 15.4625C9.9209 15.3913 9.6758 15.2562 9.47812 15.0701C9 14.6198 9 13.7465 9 12C9 10.2535 9 9.38018 9.47812 8.92995C9.6758 8.74381 9.9209 8.60868 10.1899 8.53753C10.8406 8.36544 11.648 8.79357 13.2629 9.64983C14.9333 10.5356 15.7686 10.9785 15.9453 11.6052C16.0182 11.8639 16.0182 12.1361 15.9453 12.3948Z' stroke='$accent'/>"
  ln -sfn io.github.celluloid_player.Celluloid.svg "$new/scalable/apps/celluloid.svg"
  dirs="scalable/apps,$dirs"
  # The icons inside apps (home, back, search, trash, the star): Takumi's own under the names every GTK app
  # asks for, the same strokes as the shell's (default/app-icons, Hugeicons shapes). They are drawn as
  # strokes in the classes GTK recolours ("foreground-stroke transparent-fill"); a plain stroke is filled in.
  for d in /usr/share/takumi/app-icons "$theme_lib_dir/../default/app-icons"; do
    [[ -d "$d" ]] || continue
    mkdir -p "$new/symbolic"; ln -sfn "$(cd "$d" && pwd)" "$new/symbolic/actions"
    dirs="symbolic/actions,$dirs"
    sections=$(printf '\n\n[symbolic/actions]\nContext=Actions\nSize=16\nMinSize=8\nMaxSize=512\nType=Scalable%s' "$sections")
    break
  done
  sections=$(printf '\n\n[scalable/apps]\nContext=Applications\nSize=64\nMinSize=16\nMaxSize=256\nType=Scalable%s' "$sections")
  printf '[Icon Theme]\nName=Takumi\nComment=Takumi squircle app icons and themed folders (takumi theme apply)\nInherits=%s,Papirus,hicolor\nDirectories=%s%s\n' \
    "$inherit" "$dirs" "$sections" > "$new/index.theme"
  printf '%s\n' "$stamp" > "$new/.takumi"
  rm -rf "$theme_icon_dir.old"
  [[ -d "$theme_icon_dir" ]] && mv "$theme_icon_dir" "$theme_icon_dir.old"
  mv "$new" "$theme_icon_dir"; rm -rf "$theme_icon_dir.old"
  printf '%s\n' "$colour"
}

# The browsers in the theme's colours (takumi theme browsers). Firefox reads a stylesheet from each
# profile's chrome/ folder once it is allowed to (toolkit.legacyUserProfileCustomizations.stylesheets, set
# in the profile's user.js); the stylesheet imports the rendered look/firefox-userChrome.css. Chromium,
# Chrome and Brave take a colour to build their theme from as a policy, a file only root may write.
theme_browsers_flag="$HOME/.config/takumi/browsers"
theme_browsers_state="$HOME/.local/state/takumi/browsers"
theme_etc="${TAKUMI_ETC:-/etc}"
theme_ff_pref='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true); // Takumi: the theme colours Firefox (takumi theme browsers)'
theme_ff_import='@import "takumi.css"; /* Takumi: the theme'"'"'s colours (takumi theme browsers) */'

# theme_firefox_profiles: every Firefox profile folder this user has, one per line.
theme_firefox_profiles() {
  local root
  for root in "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox" "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"; do
    [[ -f "$root/profiles.ini" ]] || continue
    awk -v root="$root" '
      /^\[/ { if (path != "") print (rel == "0" ? path : root "/" path); path = ""; rel = "1"; next }
      /^Path=/ { path = substr($0, 6) }
      /^IsRelative=/ { rel = substr($0, 12) }
      END { if (path != "") print (rel == "0" ? path : root "/" path) }' "$root/profiles.ini"
  done | while IFS= read -r p; do [[ -d "$p" ]] && printf '%s\n' "$p"; done
  return 0
}

# theme_firefox_wire <profile>: the profile wears the theme from its next start. Your own user.js and
# userChrome.css lines are kept; Takumi's are one line each, marked.
theme_firefox_wire() {
  local p=$1 css rest
  [[ -f "$p/user.js" ]] && grep -qF "$theme_ff_pref" "$p/user.js" || printf '%s\n' "$theme_ff_pref" >> "$p/user.js"
  mkdir -p "$p/chrome"
  ln -sfn "$theme_look/firefox-userChrome.css" "$p/chrome/takumi.css"
  css="$p/chrome/userChrome.css"
  if [[ ! -f "$css" ]]; then printf '%s\n' "$theme_ff_import" > "$css"
  elif ! grep -qF "$theme_ff_import" "$css"; then
    rest=$(cat "$css"); printf '%s\n%s\n' "$theme_ff_import" "$rest" > "$css"   # an @import must come first
  fi
}

# theme_firefox_unwire <profile>: Takumi's lines and link go; yours stay.
theme_firefox_unwire() {
  local p=$1 f rest
  rm -f "$p/chrome/takumi.css"
  for f in "$p/chrome/userChrome.css" "$p/user.js"; do
    [[ -f "$f" ]] || continue
    rest=$(grep -vF -e "$theme_ff_import" -e "$theme_ff_pref" "$f" || true)
    if [[ -n "$rest" ]]; then printf '%s\n' "$rest" > "$f"; else rm -f "$f"; fi
  done
}

# theme_chromium_policies: the policy file for each Chromium-family browser installed, one per line.
theme_chromium_policies() {
  command -v chromium >/dev/null && echo "$theme_etc/chromium/policies/managed/takumi-theme.json"
  command -v google-chrome-stable >/dev/null && echo "$theme_etc/opt/chrome/policies/managed/takumi-theme.json"
  { command -v brave >/dev/null || command -v brave-browser >/dev/null; } && echo "$theme_etc/brave/policies/managed/takumi-theme.json"
  return 0
}

# theme_chromium_colour: the colour the policies hold now, or nothing.
theme_chromium_colour() {
  local f
  f=$(theme_chromium_policies | head -n 1)
  [[ -n "$f" && -f "$f" ]] || return 0
  sed -n 's/.*"BrowserThemeColor" *: *"\(#[0-9a-fA-F]\{6\}\)".*/\1/p' "$f" | head -n 1
}

# theme_chromium_flags <dark|light>: Chromium's dark mode follows the theme. The flag lives in
# ~/.config/chromium-flags.conf, which Arch's chromium reads at start; Takumi removes only a flag it added.
theme_chromium_flags() {
  local f="$HOME/.config/chromium-flags.conf" added rest
  added=$(cat "$theme_browsers_state" 2>/dev/null || true)
  if [[ "$1" == dark ]]; then
    [[ -f "$f" ]] && grep -qx -- '--force-dark-mode' "$f" && return 0
    mkdir -p "${f%/*}" "${theme_browsers_state%/*}"; printf '%s\n' '--force-dark-mode' >> "$f"; printf 'flag\n' > "$theme_browsers_state"
  elif [[ "$added" == flag && -f "$f" ]]; then
    rest=$(grep -vx -- '--force-dark-mode' "$f" || true)
    if [[ -n "$rest" ]]; then printf '%s\n' "$rest" > "$f"; else rm -f "$f"; fi
    rm -f "$theme_browsers_state"
  fi
}

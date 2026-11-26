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
  <g transform="translate(16 16) scale(1.3333)" fill="none" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.65">
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
  stamp="$colour $inherit $accent $sf $bg $fg v2"
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
  # Bespoke Takumi squircle app icons for core bundled utilities so All apps speaks one design language.
  mkdir -p "$new/scalable/apps"
  theme_app_svg "$new/scalable/apps/foot.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<rect x='3' y='4.5' width='18' height='15' rx='3' stroke='$fg' stroke-opacity='0.78'/><path d='M7.5 9.5l3 2.5-3 2.5' stroke='$accent'/><path d='M12.5 15h4' stroke='$accent'/>"
  ln -sfn foot.svg "$new/scalable/apps/utilities-terminal.svg"
  theme_app_svg "$new/scalable/apps/btop.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<path d='M3 12h4l2.5-6 4 12 2.5-6H21' stroke='$accent'/><path d='M4 18.5h16' stroke='$fg' stroke-opacity='0.35'/>"
  ln -sfn btop.svg "$new/scalable/apps/utilities-system-monitor.svg"
  theme_app_svg "$new/scalable/apps/org.gnome.Nautilus.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<path d='M3.5 7.5a2 2 0 0 1 2-2h4l2 2h7a2 2 0 0 1 2 2v7.5a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z' stroke='$accent' fill='$accent' fill-opacity='0.18'/>"
  ln -sfn org.gnome.Nautilus.svg "$new/scalable/apps/system-file-manager.svg"
  theme_app_svg "$new/scalable/apps/org.gnome.TextEditor.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<path d='M6.5 4h8l4 4v11.5a1.5 1.5 0 0 1-1.5 1.5h-10.5A1.5 1.5 0 0 1 5 19.5v-14A1.5 1.5 0 0 1 6.5 4z' stroke='$fg' stroke-opacity='0.82'/><path d='M8.5 11.5h7M8.5 15.5h4.5' stroke='$accent'/>"
  ln -sfn org.gnome.TextEditor.svg "$new/scalable/apps/accessories-text-editor.svg"
  theme_app_svg "$new/scalable/apps/org.gnome.Loupe.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<rect x='3.5' y='5' width='17' height='14' rx='2.5' stroke='$fg' stroke-opacity='0.78'/><circle cx='9' cy='10' r='1.7' stroke='$accent'/><path d='M20 15.5l-4.8-4.8-8.7 8.3' stroke='$accent'/>"
  ln -sfn org.gnome.Loupe.svg "$new/scalable/apps/loupe.svg"
  theme_app_svg "$new/scalable/apps/org.gnome.Evince.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<path d='M7 3.5h6.5L18 8v11a1.5 1.5 0 0 1-1.5 1.5h-9.5A1.5 1.5 0 0 1 5.5 19V5A1.5 1.5 0 0 1 7 3.5z' stroke='$fg' stroke-opacity='0.82'/><path d='M13.5 3.5V8H18' stroke='$fg' stroke-opacity='0.55'/><path d='M8.5 12.5h7M8.5 16h5' stroke='$accent'/>"
  ln -sfn org.gnome.Evince.svg "$new/scalable/apps/org.gnome.Papers.svg"
  theme_app_svg "$new/scalable/apps/org.gnome.baobab.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<circle cx='12' cy='12' r='8.5' stroke='$fg' stroke-opacity='0.35'/><path d='M12 3.5A8.5 8.5 0 1 1 5.2 17.1' stroke='$accent'/><circle cx='12' cy='12' r='3' stroke='$fg' stroke-opacity='0.8'/>"
  theme_app_svg "$new/scalable/apps/io.github.celluloid_player.Celluloid.svg" "$sf" "$bg" "$accent" "$fg" "$light" \
    "<rect x='3.5' y='5' width='17' height='14' rx='3' stroke='$fg' stroke-opacity='0.78'/><path d='M10 9.2l5.6 2.8-5.6 2.8z' stroke='$accent' fill='$accent' fill-opacity='0.24'/>"
  ln -sfn io.github.celluloid_player.Celluloid.svg "$new/scalable/apps/celluloid.svg"
  dirs="scalable/apps,$dirs"
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

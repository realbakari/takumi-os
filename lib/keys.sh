#!/usr/bin/env bash
# Keyboards and input methods, for commands/keys/layout, commands/keys/input and the Palette's keyboard rows.
# Sourced after lib/setup.sh (its list of layouts without Latin letters and its console keymaps); runs on
# bash 3.2, as the tests do on macOS with fake tools. See docs/harmony-keys.md, "Layouts and input methods".
#
# The keyboards are the system's, kept by systemd-localed: niri follows its layout list the moment it changes,
# the login screen reads the same from /etc/vconsole.conf, and the disk's password prompt types with the
# console keymap (KEYMAP) built into the initramfs. A list is "us,de" with variants ",nodeadkeys".

# keys_load: the system's keyboard settings into KEYS_LAYOUTS, KEYS_MODEL, KEYS_VARIANTS, KEYS_OPTIONS and
# KEYS_KEYMAP. Returns 1 when systemd-localed does not answer.
keys_load() {
  local out
  out=$(busctl get-property org.freedesktop.locale1 /org/freedesktop/locale1 org.freedesktop.locale1 \
          X11Layout X11Model X11Variant X11Options VConsoleKeymap 2>/dev/null) || return 1
  [[ $(grep -c '^s "' <<< "$out" || true) -ge 5 ]] || return 1
  out=$(sed -n 's/^s "\(.*\)"$/\1/p' <<< "$out")   # empty values at the end go, and read as empty below
  KEYS_LAYOUTS=""; KEYS_MODEL=""; KEYS_VARIANTS=""; KEYS_OPTIONS=""; KEYS_KEYMAP=""
  { IFS= read -r KEYS_LAYOUTS; IFS= read -r KEYS_MODEL; IFS= read -r KEYS_VARIANTS; IFS= read -r KEYS_OPTIONS
    IFS= read -r KEYS_KEYMAP; } <<< "$out" || true
}

# keys_pairs <layouts> <variants>: one keyboard per line, layout <tab> variant. With no layout set at all,
# niri types US English, so that is the list.
keys_pairs() {
  local ls vs i
  [[ -n "$1" ]] || { printf 'us\t\n'; return 0; }
  IFS=, read -r -a ls <<< "$1"
  IFS=, read -r -a vs <<< "$2"
  for i in "${!ls[@]}"; do [[ -n "${ls[$i]}" ]] && printf '%s\t%s\n' "${ls[$i]}" "${vs[$i]:-}"; done
  return 0
}

# keys_join <1|2>: the layouts (1) or the variants (2) of the pairs on stdin, joined by commas. Variants that
# are all empty join to nothing.
keys_join() {
  local out
  out=$(cut -f "$1" | paste -sd , -)
  [[ "$1" == 2 && -z "${out//,/}" ]] && out=""
  printf '%s' "$out"
}

# Every layout and variant xkeyboard-config knows, by name (takumi setup keyboards), read once.
KEYS_ALL=""
keys_all() {
  [[ -n "$KEYS_ALL" ]] || KEYS_ALL=$(takumi setup keyboards 2>/dev/null || true)
  printf '%s\n' "$KEYS_ALL"
}

# keys_name <layout> [variant]: "German (no dead keys)"; the codes when xkeyboard-config does not list it.
keys_name() {
  local n
  n=$(keys_all | L=$1 V=${2:-} jq -r 'select(.layout == env.L and .variant == env.V) | .name' 2>/dev/null | head -n 1)
  [[ -n "$n" ]] && printf '%s' "$n" || printf '%s%s' "$1" "${2:+ ($2)}"
}

# keys_known <layout> [variant]: true when xkeyboard-config lists it.
keys_known() {
  local hit
  hit=$(keys_all | L=$1 V=${2:-} jq -r 'select(.layout == env.L and .variant == env.V) | .layout' 2>/dev/null | head -n 1)
  [[ -n "$hit" ]]
}

# keys_names: the pairs on stdin by name, joined: "English (US), German".
keys_names() {
  local l v out=""
  while IFS=$'\t' read -r l v; do
    [[ -n "$l" ]] || continue
    out+="${out:+, }$(keys_name "$l" "$v")"
  done
  printf '%s' "$out"
}

# keys_password <pairs>: the keyboard a password is typed with, layout <tab> variant: the first one, or US
# English when the first types no Latin letters (the login screen puts it first then, as setup does).
keys_password() {
  local first l v
  first=$(head -n 1 <<< "$1")
  setup_latin "${first%%$'\t'*}" && { printf '%s' "$first"; return 0; }
  while IFS=$'\t' read -r l v; do [[ "$l" == us ]] && { printf 'us\t%s' "$v"; return 0; }; done <<< "$1"
  printf 'us\t'
}

# keys_find <words>: the keyboards whose name has every word (or whose code is one), as JSON lines, layouts
# before their variants and shorter names first, at most <limit> (default 8).
keys_find() {
  keys_all | Q=$1 N=${2:-8} jq -sc '
    (env.Q | ascii_downcase | split(" ") | map(select(length > 0))) as $w
    | map(. as $k | select($w | length > 0) | select(all($w[]; . as $x | ($k.name | ascii_downcase | contains($x)) or $k.layout == $x or $k.variant == $x)))
    | sort_by([(.variant != ""), (.name | length), .name]) | .[0:(env.N | tonumber)][]' 2>/dev/null
}

# keys_pick <answer>: what a typed answer names. "one <tab> layout <tab> variant <tab> name" when it is clear:
# the only match, a name typed whole, a layout's code, or the shortest when every match is one layout;
# "several <tab> some names" when it is not; "none".
keys_pick() {
  keys_all | Q=$1 jq -rs '
    (env.Q | ascii_downcase | split(" ") | map(select(length > 0))) as $w
    | (env.Q | ascii_downcase | gsub("^ +| +$"; "")) as $whole
    | def one: "one\t" + .layout + "\t" + .variant + "\t" + .name;
    map(. as $k | select($w | length > 0) | select(all($w[]; . as $x | ($k.name | ascii_downcase | contains($x)) or $k.layout == $x or $k.variant == $x)))
    | if length == 0 then "none"
      elif length == 1 then .[0] | one
      elif any(.[]; (.name | ascii_downcase) == $whole) then first(.[] | select((.name | ascii_downcase) == $whole)) | one
      elif any(.[]; .variant == "" and .layout == $whole) then first(.[] | select(.variant == "" and .layout == $whole)) | one
      elif (map(.layout) | unique | length) == 1 then sort_by(.name | length) | .[0] | one
      else "several\t" + (sort_by([(.variant != ""), (.name | length), .name]) | (.[0:3] | map(.name) | join(", ")) + (if length > 3 then ", …" else "" end))
      end' 2>/dev/null || echo none
}

# --- Input methods: fcitx5 with one engine per way of typing.

# name | fcitx5's engine | its package | the mark | what it types | the engine's own name | its keys
keys_input_table() {
  cat <<'TABLE'
japanese|mozc|fcitx5-mozc|あ|Japanese|Mozc|Ctrl+Space, or 半角/全角 on a Japanese keyboard
korean|hangul|fcitx5-hangul|한|Korean|Hangul|Ctrl+Space, or 한/영 on a Korean keyboard
pinyin|pinyin|fcitx5-chinese-addons|拼|Chinese (Pinyin)|Pinyin|Ctrl+Space
zhuyin|chewing|fcitx5-chewing|注|Chinese (Zhuyin)|Chewing|Ctrl+Space
cangjie|cangjie5|fcitx5-table-extra|倉|Chinese (Cangjie)|Cangjie 5|Ctrl+Space
TABLE
}
KEYS_INPUT_NAMES="japanese korean pinyin zhuyin cangjie"
KEYS_INPUT_BASE="fcitx5 fcitx5-gtk fcitx5-qt"   # the input method, and its doors into GTK and Qt apps

# keys_input_get <name or engine> <field 1-7>: a field of the table, or nothing.
keys_input_get() { keys_input_table | awk -F '|' -v k="$1" -v f="$2" '$1 == k || $2 == k { print $f; exit }'; }

keys_input_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5"

# keys_input_engines: the engines in fcitx5's profile, in order; its keyboards ("keyboard-us") left out.
keys_input_engines() {
  [[ -f "$keys_input_dir/profile" ]] || return 0
  awk -F '=' '/^\[Groups\/0\/Items\/[0-9]+\]$/ { item = 1; next } /^\[/ { item = 0 }
              item && $1 == "Name" && $2 !~ /^keyboard-/ && $2 != "" { print $2 }' "$keys_input_dir/profile"
}

# keys_input_base <pairs>: fcitx5's name for the keyboard under the engines, the one a password is typed with:
# "us", "de-nodeadkeys".
keys_input_base() {
  local p l v
  p=$(keys_password "$1"); l=${p%%$'\t'*}; v=${p#*$'\t'}
  printf '%s%s' "$l" "${v:+-$v}"
}

# keys_input_write <base> <engines, one per line> <the one Ctrl+Space turns on>: fcitx5's profile, written whole.
# fcitx5 writes this file itself when it stops, so it must not be running.
keys_input_write() {
  local base=$1 engines=$2 on=$3 i=0 e
  mkdir -p "$keys_input_dir"
  {
    printf '[Groups/0]\n# Group Name\nName=Default\n# Layout\nDefault Layout=%s\n# Default Input Method\nDefaultIM=%s\n\n' "$base" "${on:-keyboard-$base}"
    for e in "keyboard-$base" $engines; do
      printf '[Groups/0/Items/%s]\n# Name\nName=%s\n# Layout\nLayout=\n\n' "$i" "$e"
      i=$((i + 1))
    done
    printf '[GroupOrder]\n0=Default\n'
  } > "$keys_input_dir/profile.new"
  mv "$keys_input_dir/profile.new" "$keys_input_dir/profile"
}

# keys_input_config: fcitx5's own settings, the first time only (fcitx5 keeps the file from then on). Ctrl+Space
# switches, as on a Mac, with the keys Japanese and Korean keyboards have for it; Super+Space stays the Core's;
# a switch holds for every app at once, as on a Mac or Windows.
keys_input_config() {
  [[ -f "$keys_input_dir/config" ]] && return 0
  mkdir -p "$keys_input_dir"
  cat > "$keys_input_dir/config" <<'CONFIG'
# Takumi's first settings for fcitx5 (takumi keys input, docs/harmony-keys.md). fcitx5 keeps this file now.
[Hotkey]
EnumerateWithTriggerKeys=True
EnumerateSkipFirst=False

[Hotkey/TriggerKeys]
0=Control+space
1=Zenkaku_Hankaku
2=Hangul

[Hotkey/EnumerateGroupForwardKeys]

[Hotkey/EnumerateGroupBackwardKeys]

[Behavior]
ShareInputState=All
CONFIG
}

# keys_input_mask: Takumi starts fcitx5 itself (keys_input_start), so its package's autostart entry never does.
keys_input_mask() {
  local f="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/org.fcitx.Fcitx5.desktop"
  [[ -f "$f" ]] && return 0
  mkdir -p "${f%/*}"
  printf '%s\n' "[Desktop Entry]" "# Takumi starts the input method when one is set up (takumi keys input start)." \
    "Type=Application" "Name=Fcitx 5" "Hidden=true" > "$f"
}

keys_input_running() { pgrep -xu "$(id -u)" fcitx5 >/dev/null 2>&1; }

# keys_input_stop: fcitx5 stops (writing its profile as it goes), and is waited for, up to three seconds.
keys_input_stop() {
  systemctl --user stop takumi-input.service >/dev/null 2>&1 || true
  keys_input_running && { fcitx5-remote -e >/dev/null 2>&1 || true; }
  local n
  for n in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do keys_input_running || return 0; sleep 0.2; done
  return 0
}

# keys_input_start: with an engine set up, fcitx5 runs in a unit of its own that ends with the session, and the
# apps the shell opens are pointed at it: X11 apps (XMODIFIERS), Qt 6.7 and later through Wayland's own text
# input first (QT_IM_MODULES), Qt 5 (QT_IM_MODULE). GTK apps, Firefox and foot use Wayland's text input and need
# nothing. With none set up, nothing runs and Qt 5 apps are no longer pointed at it.
keys_input_start() {
  if [[ -z "$(keys_input_engines)" ]] || ! command -v fcitx5 >/dev/null; then
    systemctl --user unset-environment QT_IM_MODULE >/dev/null 2>&1 || true
    return 0
  fi
  systemctl --user set-environment XMODIFIERS=@im=fcitx "QT_IM_MODULES=wayland;fcitx" QT_IM_MODULE=fcitx >/dev/null 2>&1 || true
  keys_input_mask
  keys_input_running && return 0
  systemd-run --user --unit=takumi-input --collect --quiet -p PartOf=graphical-session.target -p After=graphical-session.target \
    fcitx5 >/dev/null 2>&1 || fcitx5 -d >/dev/null 2>&1 || true
}

# --- The pointer, the touchpad and key repeat: ~/.config/niri/takumi/input.kdl, which Takumi's defaults.kdl
# includes after its own input block (takumi keys pointer, docs/laptop-keys.md). niri does not merge a pointing
# device's block from two files, so the file restates every touchpad and mouse setting defaults.kdl makes, with
# your choices in place. niri reads it again by itself when it changes.

keys_pointer_file="${XDG_CONFIG_HOME:-$HOME/.config}/niri/takumi/input.kdl"
# libinput's pointer speed, slowest first; 0.0 is libinput's own and Takumi's.
keys_speeds="-0.6 -0.4 -0.2 0.0 0.2 0.4 0.6 0.8"
# Key repeat as <wait before it starts, ms>/<keys a second>, slowest first; 280/40 is Takumi's.
keys_repeats="600/15 450/22 350/30 280/40 220/50 180/60"

# keys_pointer_load: the settings in force into KEYS_NATURAL and KEYS_TAP (yes or no), KEYS_SPEED, KEYS_DELAY and
# KEYS_RATE. Without the file, Takumi's: natural scrolling and tap to click on, speed 0.0, 280 ms and 40 a second.
keys_pointer_load() {
  KEYS_NATURAL=yes; KEYS_TAP=yes; KEYS_SPEED=0.0; KEYS_DELAY=280; KEYS_RATE=40
  [[ -f "$keys_pointer_file" ]] || return 0
  local tp
  # The touchpad's block alone: a mouse's settings never decide the touchpad's.
  tp=$(awk '/^[[:space:]]*touchpad[[:space:]]*\{/ { in_tp = 1; next } in_tp && /^[[:space:]]*\}/ { in_tp = 0 } in_tp' "$keys_pointer_file")
  grep -qE '^[[:space:]]*natural-scroll[[:space:]]*$' <<< "$tp" || KEYS_NATURAL=no
  grep -qE '^[[:space:]]*tap[[:space:]]*$' <<< "$tp" || KEYS_TAP=no
  KEYS_SPEED=$(sed -n 's/^[[:space:]]*accel-speed[[:space:]]\{1,\}\(-\{0,1\}[0-9.]\{1,\}\)[[:space:]]*$/\1/p' <<< "$tp" | head -n 1)
  KEYS_DELAY=$(sed -n 's/^[[:space:]]*repeat-delay[[:space:]]\{1,\}\([0-9]\{1,\}\)[[:space:]]*$/\1/p' "$keys_pointer_file" | head -n 1)
  KEYS_RATE=$(sed -n 's/^[[:space:]]*repeat-rate[[:space:]]\{1,\}\([0-9]\{1,\}\)[[:space:]]*$/\1/p' "$keys_pointer_file" | head -n 1)
  KEYS_SPEED=${KEYS_SPEED:-0.0}; KEYS_DELAY=${KEYS_DELAY:-280}; KEYS_RATE=${KEYS_RATE:-40}
}

# keys_pointer_write: input.kdl, written whole from KEYS_NATURAL, KEYS_TAP, KEYS_SPEED, KEYS_DELAY and KEYS_RATE.
keys_pointer_write() {
  mkdir -p "${keys_pointer_file%/*}"
  {
    printf '%s\n' "// Your pointer, touchpad and key repeat from the Core (takumi keys pointer, docs/laptop-keys.md)." \
      "// Written whole by that command; your own input settings go in overrides.kdl, which wins." \
      "input {" "    keyboard {" "        repeat-delay $KEYS_DELAY" "        repeat-rate $KEYS_RATE" "        numlock" "    }" "    touchpad {"
    [[ $KEYS_TAP == yes ]] && printf '        tap\n'
    [[ $KEYS_NATURAL == yes ]] && printf '        natural-scroll\n'
    printf '%s\n' "        dwt" "        accel-profile \"adaptive\"" "        accel-speed $KEYS_SPEED" "        click-method \"clickfinger\"" \
      "        scroll-factor 0.5" "    }" "    mouse {" "        accel-profile \"flat\"" "        accel-speed $KEYS_SPEED" "    }" "}"
  } > "$keys_pointer_file.new"
  mv "$keys_pointer_file.new" "$keys_pointer_file"
}

# keys_step <list> <now> <1|-1>: the value one step from the one nearest <now> in a list of numbers (or of
# <number>/<number>, by the first), or nothing past either end.
keys_step() {
  awk -v list="$1" -v now="$2" -v dir="$3" 'BEGIN {
    n = split(list, v, " "); split(now, cur, "/"); best = 1
    for (i = 1; i <= n; i++) { split(v[i], x, "/"); split(v[best], b, "/")
      d1 = x[1] - cur[1]; if (d1 < 0) d1 = -d1; d2 = b[1] - cur[1]; if (d2 < 0) d2 = -d2
      if (d1 < d2) best = i }
    i = best + dir; if (i >= 1 && i <= n) print v[i] }'
}

# keys_place <list> <now>: "<position> of <count>" for the value nearest <now>, counted from the slowest.
keys_place() {
  awk -v list="$1" -v now="$2" 'BEGIN {
    n = split(list, v, " "); split(now, cur, "/"); best = 1
    for (i = 1; i <= n; i++) { split(v[i], x, "/"); split(v[best], b, "/")
      d1 = x[1] - cur[1]; if (d1 < 0) d1 = -d1; d2 = b[1] - cur[1]; if (d2 < 0) d2 = -d2
      if (d1 < d2) best = i }
    print best " of " n }'
}

# --- The top row: function keys or media keys first (takumi keys fn, docs/laptop-keys.md). Apple's keyboards
# through the hid_apple driver's fnmode (1 media keys first, 2 function keys first); laptops whose driver shows a
# switch for the Fn lock (Lenovo's ideapad: fn_lock; Huawei's: fn_lock_state; 1 function keys first).
keys_sys=${TAKUMI_SYS:-/sys}
keys_fn_apple() { [[ -r "$keys_sys/module/hid_apple/parameters/fnmode" ]] && printf '%s\n' "$keys_sys/module/hid_apple/parameters/fnmode"; }
# keys_fn_locks: every Fn lock switch a laptop's driver shows, one path per line.
keys_fn_locks() {
  local f
  for f in "$keys_sys"/bus/platform/devices/*/fn_lock "$keys_sys"/devices/platform/huawei-wmi/fn_lock_state; do
    [[ -r "$f" ]] && printf '%s\n' "$f"
  done
  return 0
}
# keys_fn_now: fkeys or media, as the computer is now, or nothing when it has no switch.
keys_fn_now() {
  local a l
  if a=$(keys_fn_apple); then
    case "$(cat "$a" 2>/dev/null)" in 2) echo fkeys ;; *) echo media ;; esac; return 0
  fi
  l=$(keys_fn_locks | head -n 1)
  [[ -n "$l" ]] || return 0
  case "$(cat "$l" 2>/dev/null)" in 1) echo fkeys ;; *) echo media ;; esac
}

# --- Alt and Super swapped, for a PC keyboard whose Alt sits beside the space bar where a Mac's Command key does
# (takumi keys harmony swap, docs/harmony-keys.md). Only the left keys trade places: the right Alt stays AltGr,
# which many layouts type with. A marked block under [main] of keyd's file.
keys_swap_begin="# Alt and Super swapped (takumi keys harmony swap)"
keys_swap_end="# End of Alt and Super swapped"
keys_swapped() { [[ -f "$1" ]] && grep -qxF "$keys_swap_begin" "$1"; }
# keys_swap_without: keyd's file on stdin without the swap: with Harmony's layer, the Windows key's line back.
keys_swap_without() {
  B=$keys_swap_begin E=$keys_swap_end awk '
    $0 == ENVIRON["B"] { skip = 1; cmd = 0; next }
    skip && $0 == "leftalt = layer(cmd)" { cmd = 1 }
    skip && $0 == ENVIRON["E"] { skip = 0; if (cmd) print "leftmeta = layer(cmd)"; next }
    !skip { print }'
}
# keys_swap_with: keyd's file on stdin with the swap. With Harmony's layer, the left Alt becomes the Command key
# and the Windows key Alt, in place of Harmony's line for the Windows key; without it, the two keys trade places,
# right under [main].
keys_swap_with() {
  local text
  text=$(keys_swap_without)
  if grep -qxF 'leftmeta = layer(cmd)' <<< "$text"; then
    B=$keys_swap_begin E=$keys_swap_end awk '
      $0 == "leftmeta = layer(cmd)" && !done { print ENVIRON["B"]; print "leftalt = layer(cmd)"; print "leftmeta = layer(alt)"; print ENVIRON["E"]; done = 1; next }
      { print }' <<< "$text"
  else
    B=$keys_swap_begin E=$keys_swap_end awk '
      function block() { print ENVIRON["B"]; print "leftalt = leftmeta"; print "leftmeta = leftalt"; print ENVIRON["E"] }
      { print } $0 == "[main]" && !done { block(); done = 1 }
      END { if (!done) { print ""; print "[main]"; block() } }' <<< "$text"
  fi
}

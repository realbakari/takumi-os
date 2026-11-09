#!/usr/bin/env bash
# Screens, text size and the night light. Sourced by commands/display/* and the Palette's display
# provider; runs on bash 3.2. See docs/display.md.
#
# A screen's scale, turn and place are read from niri (`niri msg --json outputs`) and changed through
# it (`niri msg output`), which niri forgets as soon as its config changes. What you keep is written
# whole to ~/.config/niri/takumi/outputs.kdl, which niri includes and watches. Text size and the night
# light live in ~/.config/takumi/display.toml, written whole too, so the file always reads the same.

display_config="$HOME/.config/takumi/display.toml"
display_outputs="$HOME/.config/niri/takumi/outputs.kdl"
display_shell="$HOME/.config/takumi/shell.toml"
display_phase="$HOME/.config/takumi/phase.toml"
display_run="${XDG_RUNTIME_DIR:-$HOME/.local/state/takumi}"

display_scales="100 125 150 175 200 250 300"   # percent: the steps "Bigger" and "Smaller" walk; dense laptop
                                               # panels and 4K screens want the top ones
display_text_sizes="11 13 15 17 20"   # the shell's font_size; 13 is the size the shell was drawn at
display_warm=3800                     # the night light's colour, in kelvin; 6500 is daylight

# display_screens: one line per screen that is on, the built-in one first, then by name:
#   name  label  percent  transform  x  y  width  height
# The label is for sentences: "the built-in screen", or the monitor's model. The transform is niri's
# word (Normal, 90, 180, 270, Flipped, Flipped90, …); x, y, width and height are logical, after scale.
display_screens() {
  niri msg --json outputs | jq -r '
    [ .[] | select(.logical != null) ] | sort_by([(.name | startswith("eDP") | not), .name]) | .[]
    | (.make // "" | split(" ") | .[0] // "" | ascii_downcase) as $mk
    | (if (.name | startswith("eDP")) then "the built-in screen"
       elif $mk != "" and $mk != "unknown" and (.model // "" | ascii_downcase | contains($mk)) then .model
       else ([.make, .model] | map(select(. != null and . != "" and . != "Unknown")) | join(" ")) end) as $label
    | [ .name, (if $label == "" then .name else $label end), (.logical.scale * 100 | round), .logical.transform,
        .logical.x, .logical.y, .logical.width, .logical.height ]
    | @tsv'
}
# display_modes <name>: the screen's modes, the most pixels first, then the fastest:
#   WxH  refresh in mHz  preferred (1 or 0)  current (1 or 0)
display_modes() {
  niri msg --json outputs | jq -r --arg n "$1" '
    ([ .[] | select(.name == $n) ][0] // {}) as $o | ($o.current_mode // -1) as $cur
    | ($o.modes // []) | to_entries
    | sort_by([-(.value.width * .value.height), -.value.refresh_rate])[]
    | [ "\(.value.width)x\(.value.height)", .value.refresh_rate,
        (if .value.is_preferred then 1 else 0 end), (if .key == $cur then 1 else 0 end) ] | @tsv'
}
# display_hz <mHz>: a refresh rate in words ("60 Hz", "59.94 Hz"); display_mode_arg <WxH> <mHz>: niri's form.
display_hz() { awk -v m="$1" 'BEGIN { h = m / 1000; r = int(h + 0.5); if (h - r < 0.01 && r - h < 0.01) printf "%d Hz", r; else printf "%.2f Hz", h }'; }
display_mode_arg() { awk -v s="$1" -v m="$2" 'BEGIN { printf "%s@%.3f", s, m / 1000 }'; }
# display_pick_mode <want>, on display_modes' lines: "WxH<TAB>mHz" for native (the screen's own), smoother
# (the fastest at the current size, when faster than now), WxH (the fastest at that size) or WxH@Hz (the
# nearest to that rate at that size); nothing when there is none.
display_pick_mode() {
  awk -F '\t' -v want="$1" '
    { size[NR] = $1; hz[NR] = $2; pref[NR] = $3; if ($4 == 1) { csize = $1; chz = $2 } }
    END {
      if (want == "native") { for (i = 1; i <= NR; i++) if (pref[i] == 1) { print size[i] "\t" hz[i]; exit } exit }
      if (want == "smoother") { b = 0; for (i = 1; i <= NR; i++) if (size[i] == csize && hz[i] > hz[b] + 0) b = i
                                if (b && hz[b] > chz + 500) print size[b] "\t" hz[b]; exit }
      split(want, w, "@"); b = 0
      for (i = 1; i <= NR; i++) {
        if (size[i] != w[1]) continue
        d = (w[2] == "") ? -hz[i] : (hz[i] - w[2] * 1000) * (hz[i] - w[2] * 1000)
        if (!b || d < bd) { b = i; bd = d }
      }
      if (b) print size[b] "\t" hz[b]
    }'
}

# display_builtin: the built-in screen's port and whether it is on ("eDP-1<TAB>on" or "eDP-1<TAB>off"),
# or nothing on a computer without one. It is off when niri turned it off, by hand or at the lid.
display_builtin() {
  niri msg --json outputs | jq -r '[ .[] | select(.name | test("^(eDP|LVDS|DSI)")) ] | sort_by(.name) | .[0] // empty
    | [ .name, (if .logical != null then "on" else "off" end) ] | @tsv'
}
# display_lid_closed: true when a laptop's lid is shut (ACPI says so); TAKUMI_LID stands in for it in tests.
display_lid_closed() {
  local f
  for f in ${TAKUMI_LID:-/proc/acpi/button/lid/*/state}; do [[ -r "$f" ]] && grep -q closed "$f" && return 0; done
  return 1
}
display_builtin_marker="$display_run/builtin-off"   # "<guard pid> <port>" while the built-in screen is off by hand

# display_pick <name>: that screen's line from display_screens on stdin.
display_pick() { awk -F '\t' -v n="$1" '$1 == n'; }

# display_next <list> <current> <bigger|smaller>: the list's next value above or below the current one.
display_next() {
  local v best=""
  for v in $1; do
    case "$3" in
      bigger)  (( v > $2 )) && { best=$v; break; } ;;
      smaller) (( v < $2 )) && best=$v ;;
    esac
  done
  printf '%s' "$best"
}
# display_factor <percent>: niri's scale for a percent: 125 is 1.25, 100 is 1.
display_factor() { awk -v p="$1" 'BEGIN { printf "%g", p / 100 }'; }
# display_transform_word <niri's transform>: the word niri's config and `niri msg output` take.
display_transform_word() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/^flipped\([0-9]\)/flipped-\1/'; }
# display_next_turn <niri's transform>: a quarter turn on; a flipped screen goes back to normal.
display_next_turn() { case "$1" in Normal) echo 90 ;; 90) echo 180 ;; 180) echo 270 ;; *) echo normal ;; esac; }

# display_change <kept> <apply> <undo> [after]: a change to a screen is a conversation (lib/core.sh).
# <apply>, <undo> and <after> are functions. The change shows at once; yes keeps it (outputs.kdl, then
# <after>), no or ten seconds of silence undo it. Exits 0 kept, 3 went back, 1 when niri would not make
# the change.
display_change() {
  display_undo=$3; display_decided=no; display_after=${4:-}
  "$2" >/dev/null 2>&1 || core_fail 1 "The screen did not change"
  trap '[[ $display_decided == yes ]] || $display_undo >/dev/null 2>&1' EXIT   # killed mid-question: back
  local rc=0 secs=${TAKUMI_DISPLAY_KEEP:-10}
  core_confirm_within "$secs" "Keep this?" || rc=$?
  if (( rc == 0 )); then
    display_persist; display_decided=yes
    [[ -z "$display_after" ]] || "$display_after"
    core_done "$1"; exit 0
  fi
  $display_undo >/dev/null 2>&1 || true
  display_decided=yes; core_done "Went back"; exit 3
}
# display_keys: "<port><TAB><name in outputs.kdl>" for each screen that is on. A monitor is kept under its
# make, model and serial, which niri matches as well as a port, so its scale and place follow it to any
# port and another monitor on that port does not inherit them. The built-in screen, a monitor that does
# not say what it is, and two that say the same are kept under their port.
display_keys() {
  niri msg --json outputs | jq -r '
    def known: . != null and . != "" and . != "Unknown";
    [ .[] | select(.logical != null)
      | ((.modes // [])[.current_mode // -1] // null) as $m
      | { name, key: (if (.name | test("^(eDP|LVDS|DSI)")) or ((.make | known) and (.model | known) | not) then .name
                      else "\(.make) \(.model) \(if (.serial | known) then .serial else "Unknown" end)" end),
          mode: (if $m == null or $m.is_preferred then "" else "\($m.width)x\($m.height)@\($m.refresh_rate)" end) } ]
    | group_by(.key) | map(if length > 1 then map(.key = .name) else . end) | add // []
    | .[] | [.name, .key, .mode] | @tsv'
}
# display_persist: outputs.kdl, so niri starts the same way next time: every screen that is on as it is
# now, and what was kept for screens that are not plugged in. niri watches the file; the reload is asked
# for all the same.
display_persist() {
  local screens keys name label pct transform x y w h key mode
  screens=$(display_screens); keys=$(display_keys)
  mkdir -p "$(dirname "$display_outputs")"
  {
    printf '// Your screens, as you kept them in the Core. Written by takumi display; see docs/display.md.\n'
    while IFS=$'\t' read -r name label pct transform x y w h; do
      [[ -n "$name" ]] || continue
      key=$(awk -F '\t' -v n="$name" '$1 == n { print $2 }' <<< "$keys")
      mode=$(awk -F '\t' -v n="$name" '$1 == n { print $3 }' <<< "$keys")
      printf 'output "%s" {\n' "${key:-$name}"
      # A mode only when it is not the screen's own, so a better one a new cable brings is taken.
      [[ -n "$mode" ]] && printf '    mode "%s"\n' "$(display_mode_arg "${mode%@*}" "${mode#*@}")"
      printf '    scale %s\n    transform "%s"\n    position x=%s y=%s\n}\n' \
        "$(display_factor "$pct")" "$(display_transform_word "$transform")" "$x" "$y"
    done <<< "$screens"
    # A block for a screen that is on, under its port or its name, was just written again; the rest stay.
    [[ -f "$display_outputs" ]] && on=$(cut -f1,2 <<< "$keys" | tr '\t' '\n') awk '
      BEGIN { n = split(ENVIRON["on"], o, "\n"); for (i = 1; i <= n; i++) if (o[i] != "") written[o[i]] = 1 }
      /^output "/ { k = $0; sub(/^output "/, "", k); sub(/" *\{ *$/, "", k); keep = !(k in written); inside = 1 }
      inside && keep { print }
      /^\}/ { inside = 0 }' "$display_outputs"
  } > "$display_outputs.tmp"
  mv "$display_outputs.tmp" "$display_outputs"
  niri msg action load-config-file >/dev/null 2>&1 || true
}

# display_setting <table> <key> <default>: a value from display.toml, a number or a quoted word.
display_setting() {
  local v=""
  [[ -f "$display_config" ]] && v=$(sed -n "/^\[$1\]/,/^\[/s/^$2 *= *\"\{0,1\}\([A-Za-z0-9.]*\).*/\1/p" "$display_config" | head -n 1)
  printf '%s' "${v:-$3}"
}
display_text_size() { display_setting text size 13; }
display_nightlight_mode() { display_setting nightlight mode off; }
# display_save <text size> <night light mode>: display.toml, written whole, so it reads the same
# however it got there (config/takumi/display.toml is this with the defaults).
display_save() {
  mkdir -p "$(dirname "$display_config")"
  {
    printf '# Text size and the night light, as set from the Core. See docs/display.md.\n'
    printf '# Screens (scale, turn, arrangement) are in ~/.config/niri/takumi/outputs.kdl.\n\n'
    printf '[text]\nsize = %s          # 11, 13, 15, 17 or 20; the Core and your apps follow\n\n' "$1"
    printf '[nightlight]\nmode = "%s"       # off | on | schedule: warm from dusk to dawn, on the clock in phase.toml\n' "$2"
  } > "$display_config.tmp"
  mv "$display_config.tmp" "$display_config"
}
# display_clock <dawn|dusk>: the time from phase.toml's schedule, the clock the sky follows.
display_clock() {
  local v=""
  [[ -f "$display_phase" ]] && v=$(sed -n "/^\[schedule\]/,/^\[/s/^$1 *= *\"\([0-9][0-9]:[0-9][0-9]\)\".*/\1/p" "$display_phase" | head -n 1)
  case "$1" in dawn) printf '%s' "${v:-05:30}" ;; *) printf '%s' "${v:-17:30}" ;; esac
}

# display_set_text <size>: the Core's font_size (shell.toml, which the shell watches) and the apps'
# text scale (gsettings; 13 is 1.00). Other lines of shell.toml are kept.
display_set_text() {
  display_save "$1" "$(display_nightlight_mode)"
  mkdir -p "$(dirname "$display_shell")"
  [[ -f "$display_shell" ]] || : > "$display_shell"
  awk -v n="$1" '/^font_size[[:space:]]*=/ { print "font_size = " n; seen = 1; next } { print } END { if (!seen) print "font_size = " n }' \
    "$display_shell" > "$display_shell.tmp"
  mv "$display_shell.tmp" "$display_shell"
  command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface text-scaling-factor "$(awk -v n="$1" 'BEGIN { printf "%.2f", n / 13 }')" 2>/dev/null || true
}

# External monitors' brightness goes over DDC/CI (ddcutil, which needs the i2c-dev module), and slowly: the
# monitors found are kept for ten minutes in $display_run/ddc. display_ddc_displays [--cached]: the numbers
# ddcutil knows them by; --cached never waits on ddcutil (the Palette), it looks again in the background.
display_ddc_detect() {
  command -v ddcutil >/dev/null || return 0
  mkdir -p "$display_run"
  ddcutil detect --brief 2>/dev/null | awk '/^Display [0-9]+/ { print $2 }' > "$display_run/ddc.tmp" && mv "$display_run/ddc.tmp" "$display_run/ddc"
}
display_ddc_displays() {
  command -v ddcutil >/dev/null || return 0
  if [[ ! -f "$display_run/ddc" ]]; then
    if [[ "${1:-}" == --cached ]]; then (display_ddc_detect >/dev/null 2>&1 &); return 0; fi
    display_ddc_detect
  elif [[ -n "$(find "$display_run/ddc" -mmin +10 2>/dev/null)" ]]; then (display_ddc_detect >/dev/null 2>&1 &); fi
  cat "$display_run/ddc" 2>/dev/null || true
}
# display_ddc_set <percent|up|down> [step]: every external monitor, five points a step unless told.
display_ddc_set() {
  local d step=${2:-5}
  for d in $(display_ddc_displays); do
    case "$1" in
      up)   ddcutil --display "$d" --noverify setvcp 10 + "$step" ;;
      down) ddcutil --display "$d" --noverify setvcp 10 - "$step" ;;
      *)    ddcutil --display "$d" --noverify setvcp 10 "$1" ;;
    esac >/dev/null 2>&1 || true
  done
}
# display_ddc_get: the first external monitor's brightness, in percent of its own range.
display_ddc_get() {
  local d v
  d=$(display_ddc_displays | head -n 1); [[ -n "$d" ]] || return 0
  v=$(ddcutil --display "$d" getvcp 10 --brief 2>/dev/null) || return 0
  awk '$5 > 0 { printf "%d", $4 * 100 / $5 }' <<< "$v"
}

# The night light is one wlsunset, known by its pid file. It runs on the phase clock, warm from dusk
# to dawn, over half an hour each way. "on" keeps it warm all day: wlsunset refuses two equal
# temperatures, so the day is one kelvin cooler, which no eye sees.
display_nightlight_pid() { cat "$display_run/nightlight.pid" 2>/dev/null || true; }
display_nightlight_running() { local p; p=$(display_nightlight_pid); [[ -n "$p" ]] && kill -0 "$p" 2>/dev/null; }
display_nightlight_stop() {
  local p; p=$(display_nightlight_pid)
  [[ -n "$p" ]] && kill "$p" 2>/dev/null || true
  rm -f "$display_run/nightlight.pid"
}
display_nightlight_start() {  # <on|schedule>
  local high=6500 cmd
  [[ "$1" == on ]] && high=$((display_warm + 1))
  display_nightlight_stop
  mkdir -p "$display_run"
  cmd=(wlsunset -t "$display_warm" -T "$high" -S "$(display_clock dawn)" -s "$(display_clock dusk)" -d 1800)
  command -v setsid >/dev/null && cmd=(setsid "${cmd[@]}")   # its own session, so it outlives the Core
  "${cmd[@]}" </dev/null >/dev/null 2>&1 &
  echo $! > "$display_run/nightlight.pid"
}

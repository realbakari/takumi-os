#!/usr/bin/env bash
# Sound through PipeWire and WirePlumber, for commands/audio/* and the Palette's sound rows. Sourced,
# not run. See docs/sound.md. Everything is read from one pw-dump (the whole graph as JSON) and turned
# into two tables of JSON lines, devices and streams; changes go through wpctl, a stream is moved with
# pw-metadata, and media players are reached through playerctl. Runs on bash 3.2 (the tests feed
# hand-written dumps to fake tools on macOS).

# Takumi's own sound files sit beside this library: /usr/share/takumi/default when installed, the
# checkout's default/ otherwise. What a person chose lives in their home; what the computer keeps (the
# speaker tuning its hardware calls for) in /var/lib/takumi/audio.
audio_default="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || true)/default"
audio_config="$HOME/.config/takumi/sound.toml"
audio_machine="${TAKUMI_AUDIO_STATE:-/var/lib/takumi/audio}"
audio_run="${XDG_RUNTIME_DIR:-$HOME/.local/state/takumi}"
audio_player_file="$HOME/.local/state/takumi/player"
audio_quality_file="$HOME/.config/pipewire/pipewire.conf.d/60-takumi-quality.conf"

# The whole graph. Fails when PipeWire is not running.
audio_dump() { pw-dump 2>/dev/null; }

# jq definitions the readers share. A node's property; a volume as a person reads it (PipeWire keeps
# volumes cubed, wpctl shows the cube root); the plain name of an output or input: from its device's
# active route when the route says what it is, the device's own name when the route is generic ("Analog
# Output" on a USB headset), and the raw description when nothing fits; and a Bluetooth codec in words.
audio_jq='
  def prop($k): (.info.props // {})[$k];
  def truthy: . == true or . == "true";
  def percent: (.channelVolumes // [1]) | max | pow(.; 1 / 3) * 100 | round;
  def names: [["out", "speaker", "Speakers"], ["out", "headphone", "Headphones"], ["out", "hdmi", "HDMI"],
              ["out", "line ?out", "Line out"], ["in", "internal|digital|dmic", "Built-in microphone"],
              ["in", "headset", "Headset microphone"], ["in", "line ?in", "Line in"], ["in", "mic", "Microphone"]];
  def plain($dir; $api; $route; $desc; $dev):
    if $api == "bluez5" then "Bluetooth: " + $desc
    elif $route == null then $desc
    else ((($route.name // "") + " " + ($route.description // "")) | ascii_downcase) as $r
      | (first(names[] | . as $n | select($n[0] == $dir and ($r | test($n[1]))) | $n[2]) // null) as $hit
      | if $hit == "HDMI" then "HDMI" + (($route.description // "") | [scan("[0-9]+$")] | if length > 0 then " " + .[0] else "" end)
        elif $hit != null then $hit
        elif (($route.description // "") | ascii_downcase | test("^(analog |digital )?(output|input)$")) then ($dev // $desc)
        else ($route.description // $desc) end
    end;
  def glyph($dir; $plain):
    if $dir == "in" then "mic" elif ($plain | startswith("Bluetooth")) then "bt"
    elif $plain == "Headphones" then "headphones" elif ($plain | startswith("HDMI")) then "display" else "vol" end;
  def codec_words($c; $profile):
    ({sbc: ["SBC", "standard quality"], sbc_xq: ["SBC XQ", "good quality"], aac: ["AAC", "good quality"],
      aac_eld: ["AAC-ELD", "good quality, short delay"], aptx: ["aptX", "high quality"], aptx_hd: ["aptX HD", "very high quality"],
      aptx_ll: ["aptX Low Latency", "good quality, short delay"], aptx_ll_duplex: ["aptX Low Latency", "good quality, short delay"],
      ldac: ["LDAC", "very high quality"], lc3plus_hr: ["LC3plus", "very high quality"], lc3: ["LC3", "high quality"],
      opus_05: ["Opus", "high quality"], opus_05_51: ["Opus", "high quality"], opus_05_71: ["Opus", "high quality"],
      opus_05_duplex: ["Opus", "high quality"], opus_05_pro: ["Opus", "very high quality"], opus_g: ["Opus", "good quality"],
      faststream: ["FastStream", "basic quality, short delay"], faststream_duplex: ["FastStream", "basic quality, short delay"],
      msbc: ["mSBC", "call quality"], cvsd: ["CVSD", "phone-call quality"], lc3_swb: ["LC3", "call quality"],
      g722: ["G.722", "call quality"]}[$c] // [($c | ascii_upcase), ""]) as $w
    | $w[0] + (if $w[1] != "" then " · " + $w[1] else "" end)
      + (if ($profile // "" | test("headset|hfp|hsp")) then ", while an app uses the microphone" else "" end);
'

# Outputs and inputs, one JSON line each, from a dump on stdin: outputs first, the one in use first among
# them, then by PipeWire priority. The sink PipeWire makes up when there is no device (auto_null) is not an
# output a person can pick, and neither is a smart filter (the speaker tuning sits in front of the speakers
# and is never chosen by itself), so both are left out. A Bluetooth device says how its sound travels.
#   {dir, id, serial, name, description, plain, short, glyph, default, priority, percent, muted, route,
#    bluetooth, address, codec, codecWords}
audio_devices() {
  jq -c "$audio_jq"'
    ([.[] | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default")
          | .metadata[]? | select(.key == "default.audio.sink" or .key == "default.audio.source") | {(.key): .value.name}] | add // {}) as $def
    | (map(select(.type == "PipeWire:Interface:Device")
           | {key: (.id | tostring), value: {api: prop("device.api"), desc: prop("device.description"), routes: (.info.params.Route // [])}}) | from_entries) as $devs
    | [ .[] | select(.type == "PipeWire:Interface:Node" and prop("node.name") != "auto_null" and prop("node.name") != "takumi-recording" and ((prop("filter.smart") | truthy) | not))
        | (prop("media.class") // "") as $class
        | (if ($class | startswith("Audio/Sink")) then "out" elif ($class | startswith("Audio/Source")) then "in" else empty end) as $dir
        | ($devs[(prop("device.id") // "" | tostring)] // null) as $d
        | (prop("card.profile.device") | tostring) as $pd
        | ((($d.routes // []) | map(select(.direction == (if $dir == "out" then "Output" else "Input" end) and (.device | tostring) == $pd)) | first) // null) as $route
        | (prop("node.description") // prop("node.name")) as $desc
        | (if (prop("node.name") // "" | startswith("bluez_")) then "bluez5" else (prop("device.api") // $d.api) end) as $api
        | plain($dir; $api; $route; $desc; $d.desc) as $plain
        | (first(.info.params.Props[]? | select(has("channelVolumes"))) // {}) as $p
        | (prop("api.bluez5.codec") // "") as $codec
        | {dir: $dir, id: .id, serial: (prop("object.serial") // .id), name: prop("node.name"), description: $desc, plain: $plain,
           short: ($plain | sub("^Bluetooth: "; "")), glyph: glyph($dir; $plain),
           default: (prop("node.name") == $def[if $dir == "out" then "default.audio.sink" else "default.audio.source" end]),
           priority: (prop("priority.session") // 0 | tonumber? // 0), percent: ($p | percent), muted: ($p.mute == true),
           route: ($route.name // ""), bluetooth: ($api == "bluez5"), address: (prop("api.bluez5.address") // ""), codec: $codec,
           codecWords: (if $codec == "" then "" else codec_words($codec; prop("api.bluez5.profile")) end)} ]
    | sort_by([(if .dir == "out" then 0 else 1 end), (if .default then 0 else 1 end), -.priority, .plain]) | .[]'
}

# What apps play and record, one JSON line each, from a dump on stdin. A stream that records a sink
# (a screen recorder taking the desktop sound) is not a microphone in use: monitor says so. The streams a
# filter runs inside the sound server (the speaker tuning, a headset's microphone bridge) share a link
# group and belong to no app, so they are left out.
#   {dir, id, app, what, percent, muted, running, monitor}
audio_streams() {
  jq -c "$audio_jq"'
    .[] | select(.type == "PipeWire:Interface:Node" and prop("node.link-group") == null)
    | (prop("media.class") // "") as $class
    | (if $class == "Stream/Output/Audio" then "out" elif $class == "Stream/Input/Audio" then "in" else empty end) as $dir
    | (first(.info.params.Props[]? | select(has("channelVolumes"))) // {}) as $p
    | {dir: $dir, id: .id, app: (prop("application.name") // prop("node.name") // "An app"), what: (prop("media.name") // ""),
       percent: ($p | percent), muted: ($p.mute == true), running: (.info.state == "running"),
       monitor: (prop("stream.capture.sink") | truthy)}'
}

# The device line for <out|in> <id|name>: the PipeWire id, the node name, or the plain name or description
# in any case; failing those, the first plain name that starts with it ("hdmi" finds "HDMI 1"). Device
# lines on stdin; prints nothing when none matches.
audio_find() {
  jq -cn --arg d "$1" --arg q "$2" '[inputs | select(.dir == $d)] as $all | ($q | ascii_downcase) as $l
    | (first($all[] | select((.id | tostring) == $q or .name == $q or any(.plain, .short, .description; ascii_downcase == $l)))
       // first($all[] | select(.plain | ascii_downcase | startswith($l)))) // empty'
}

# Say why, in words, where the person is (a notice in the Core, the line at a terminal), and exit.
audio_fail() { takumi notice mute "$2" >/dev/null 2>&1 || true; printf '%s\n' "$2"; exit "$1"; }

# audio_move <out|in> <device line> <dump>: make it the default and move every stream of that kind to it.
# The streams are pinned with pw-metadata rather than left to follow the default, so a stream that an app
# or another tool pointed elsewhere moves too. A recording of the desktop sound stays where it is.
audio_move() {
  local dir=$1 dev=$2 dump=$3 id serial plain s
  IFS=$'\t' read -r id serial plain <<< "$(jq -r '[.id, .serial, .plain] | @tsv' <<< "$dev")"
  wpctl set-default "$id" >/dev/null 2>&1 || audio_fail 1 "Could not switch to $plain"
  while IFS= read -r s; do
    if [[ -n "$s" ]]; then pw-metadata "$s" target.object "$serial" >/dev/null 2>&1 || true; fi
  done <<< "$(audio_streams <<< "$dump" | jq -r --arg d "$dir" 'select(.dir == $d and (.monitor | not)) | .id')"
}

# audio_switch <out|in> <id|name>: send sound to an output, or use a microphone, by name. Exit 1 sound is
# not running, 3 no such device.
audio_switch() {
  local dir=$1 q=$2 dump dev plain glyph
  dump=$(audio_dump) || audio_fail 1 "Sound is not running"
  dev=$(audio_devices <<< "$dump" | audio_find "$dir" "$q")
  if [[ -z "$dev" ]]; then
    [[ $dir == out ]] && audio_fail 3 "There is no output called $q"
    audio_fail 3 "There is no microphone called $q"
  fi
  audio_move "$dir" "$dev" "$dump"
  IFS=$'\t' read -r plain glyph <<< "$(jq -r '[.plain, .glyph] | @tsv' <<< "$dev")"
  if [[ $dir == out ]]; then
    takumi notice "$glyph" "$plain" "Sound goes here" >/dev/null 2>&1 || true
    echo "Sound goes to $plain"
  else
    takumi notice mic "$plain" "Your microphone" >/dev/null 2>&1 || true
    echo "$plain is now your microphone"
  fi
}

# audio_next <out|in>: the next output or microphone, in a fixed order (by priority, then by name), so the
# key goes round them all. The Core names it: "Sound: AirPods Pro", with its volume. Exit 1 sound is not
# running, 3 there is none.
audio_next() {
  local dir=$1 dump dev glyph short pct muted
  dump=$(audio_dump) || audio_fail 1 "Sound is not running"
  dev=$(audio_devices <<< "$dump" | jq -sc --arg d "$dir" '[.[] | select(.dir == $d)] | sort_by([-.priority, .plain]) as $all
    | ($all | length) as $n | ([$all[].default] | index(true)) as $i
    | if $n == 0 then empty else $all[(($i // -1) + 1) % $n] end')
  if [[ -z "$dev" ]]; then
    [[ $dir == out ]] && audio_fail 3 "There is no output"
    audio_fail 3 "There is no microphone"
  fi
  audio_move "$dir" "$dev" "$dump"
  IFS=$'\t' read -r glyph short pct muted <<< "$(jq -r '[.glyph, .short, .percent, .muted] | @tsv' <<< "$dev")"
  if [[ $dir == out ]]; then
    takumi notice "$glyph" "Sound: $short" "$([[ $muted == true ]] && echo muted || true)" "$pct" >/dev/null 2>&1 || true
    echo "Sound: $short"
  else
    takumi notice mic "Microphone: $short" >/dev/null 2>&1 || true
    echo "Microphone: $short"
  fi
}

# audio_level <sink|source>: "<0-100> <muted yes|no>" for the output or microphone in use, from wpctl,
# which answers faster than a whole dump (the volume keys repeat). Fails when there is none.
audio_level() {
  local target=@DEFAULT_AUDIO_SINK@ v
  [[ $1 == source ]] && target=@DEFAULT_AUDIO_SOURCE@
  v=$(wpctl get-volume "$target" 2>/dev/null) || return 1
  [[ "$v" == Volume:* ]] || return 1
  awk '{ printf "%d %s\n", $2 * 100 + 0.5, (index($0, "MUTED") ? "yes" : "no") }' <<< "$v"
}

# audio_set_app <stream id> <0-100|mute|unmute>: one app's own volume. Setting a level also unmutes, so
# a person who asks for 50% hears it. Exit 1 sound is not running, 2 not a level, 3 no such stream.
audio_set_app() {
  local id=$1 level=$2 dump line app pct
  case "$level" in
    mute | unmute) ;;
    *) [[ "$level" =~ ^[0-9]+$ && "$level" -le 100 ]] || { echo "usage: takumi audio app <stream id> <0-100|mute|unmute>" >&2; exit 2; } ;;
  esac
  dump=$(audio_dump) || audio_fail 1 "Sound is not running"
  line=$(audio_streams <<< "$dump" | jq -cn --arg id "$id" 'first(inputs | select((.id | tostring) == $id))')
  [[ -n "$line" ]] || audio_fail 3 "No app is playing with the number $id"
  IFS=$'\t' read -r app pct <<< "$(jq -r '[.app, .percent] | @tsv' <<< "$line")"
  case "$level" in
    mute)
      wpctl set-mute "$id" 1 >/dev/null 2>&1 || audio_fail 1 "Could not mute $app"
      takumi notice mute "$app" "Muted" 0 >/dev/null 2>&1 || true; echo "$app is muted" ;;
    unmute)
      wpctl set-mute "$id" 0 >/dev/null 2>&1 || audio_fail 1 "Could not unmute $app"
      takumi notice vol "$app" "" "$pct" >/dev/null 2>&1 || true; echo "$app is back on at $pct%" ;;
    *)
      { wpctl set-volume -l 1.0 "$id" "$level%" && wpctl set-mute "$id" 0; } >/dev/null 2>&1 || audio_fail 1 "Could not set $app to $level%"
      takumi notice vol "$app" "" "$level" >/dev/null 2>&1 || true; echo "$app at $level%" ;;
  esac
}

# One line for the resting Core: <volume 0-100> <muted yes|no> <output name> <mic in use yes|no>. The
# output name can hold spaces, so a reader takes the first two words and the last, and the name is what
# is between. With no output, or no PipeWire, the volume is -1 and the name is "No output".
audio_state() {
  local dump devices streams out mic
  if dump=$(audio_dump); then
    devices=$(audio_devices <<< "$dump"); streams=$(audio_streams <<< "$dump")
    out=$(jq -rn 'first(inputs | select(.dir == "out" and .default)) | "\(.percent) \(if .muted then "yes" else "no" end) \(.plain)"' <<< "$devices")
    mic=$(jq -rn '[inputs | select(.dir == "in" and .running and (.monitor | not))] | if length > 0 then "yes" else "no" end' <<< "$streams")
  fi
  printf '%s %s\n' "${out:--1 no No output}" "${mic:-no}"
}

# Three words for the resting Core's privacy marks: <microphone in use yes|no> <camera in use yes|no>
# <microphone muted yes|no>. A camera counts when an app takes video through PipeWire (the way the camera
# portal hands it over); an app that opens /dev/video itself is not seen.
audio_marks() {
  local dump
  dump=$(audio_dump) || { echo "no no no"; return 0; }
  jq -r "$audio_jq"'
    ([.[] | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default") | .metadata[]?
       | select(.key == "default.audio.source") | .value.name] | first) as $source
    | [.[] | select(.type == "PipeWire:Interface:Node")] as $nodes
    | [$nodes[] | select(.info.state == "running") | .info.props // {}] as $on
    | [any($on[]; .["media.class"] == "Stream/Input/Audio" and .["node.link-group"] == null and ((.["stream.capture.sink"] | truthy) | not)),
       any($on[]; .["media.class"] == "Stream/Input/Video"),
       any($nodes[]; $source != null and prop("node.name") == $source and ((first(.info.params.Props[]? | select(has("mute"))) // {}) | .mute == true))]
    | map(if . then "yes" else "no" end) | join(" ")' <<< "$dump"
}

# Media players (MPRIS), through playerctl. The one the media keys control is remembered by name in
# ~/.local/state/takumi/player; while it is closed the keys reach another of its kind (a new Firefox window
# is still Firefox), then whichever player is open.
audio_players() { playerctl -l 2>/dev/null | awk 'NF && !seen[$0]++' || true; }
audio_player_chosen() {
  local p=""
  if [[ -r "$audio_player_file" ]]; then IFS= read -r p < "$audio_player_file" || true; fi
  printf '%s' "$p"
}
# A player's kind: "firefox.instance_1_23" is firefox; a name without an instance is its own kind.
audio_player_kind() { printf '%s' "${1%%.instance*}"; }
# The players the keys try, in order, for playerctl --player.
audio_player_targets() {
  local p kind; p=$(audio_player_chosen); kind=$(audio_player_kind "$p")
  if [[ -z "$p" ]]; then echo "%any"
  elif [[ "$kind" != "$p" ]]; then echo "$p,$kind,%any"
  else echo "$p,%any"; fi
}
# A player's name as a person reads it.
audio_player_name() {
  local k lower; k=$(audio_player_kind "$1"); k=${k##*.}
  lower=$(printf '%s' "$k" | tr '[:upper:]' '[:lower:]')
  case "$lower" in
    firefox) echo Firefox ;; chromium) echo Chromium ;; chrome | google-chrome) echo Chrome ;; brave | brave-browser) echo Brave ;;
    spotify) echo Spotify ;; vlc) echo VLC ;; mpv) echo mpv ;; celluloid) echo Celluloid ;; showtime | totem) echo Videos ;;
    rhythmbox) echo Rhythmbox ;; *) printf '%s%s\n' "$(printf '%s' "${k:0:1}" | tr '[:lower:]' '[:upper:]')" "${k:1}" ;;
  esac
}
# The player the keys reach now: the chosen one, one of its kind, or the first open. Fails when none is open.
audio_player_now() {
  local chosen kind players p
  players=$(audio_players); [[ -n "$players" ]] || return 1
  chosen=$(audio_player_chosen); kind=$(audio_player_kind "$chosen")
  if [[ -n "$chosen" ]]; then
    while IFS= read -r p; do if [[ "$p" == "$chosen" ]]; then echo "$p"; return 0; fi; done <<< "$players"
    while IFS= read -r p; do if [[ "$(audio_player_kind "$p")" == "$kind" ]]; then echo "$p"; return 0; fi; done <<< "$players"
  fi
  head -n 1 <<< "$players"
}
# audio_player_choose <next|previous|name>: which player the media keys control, remembered; the Core names
# it. A name is playerctl's, its kind ("spotify") or the name a person reads ("Spotify"). Exit 3 when no
# player is open or none has that name.
audio_player_choose() {
  local want=$1 players now p n=0 at=-1 pick="" name track lower
  players=$(audio_players)
  [[ -n "$players" ]] || audio_fail 3 "No media app is open"
  case "$want" in
    next | previous)
      now=$(audio_player_now || true)
      while IFS= read -r p; do [[ "$p" == "$now" ]] && at=$n; n=$((n + 1)); done <<< "$players"
      if [[ $want == next ]]; then at=$(( (at + 1) % n )); else at=$(( (at - 1 + n) % n )); fi
      n=0; while IFS= read -r p; do [[ $n -eq $at ]] && pick=$p; n=$((n + 1)); done <<< "$players" ;;
    *)
      lower=$(printf '%s' "$want" | tr '[:upper:]' '[:lower:]')
      while IFS= read -r p; do
        if [[ -z "$pick" ]] && { [[ "$p" == "$want" ]] || [[ "$(audio_player_kind "$p")" == "$want" ]] ||
             [[ "$(audio_player_name "$p" | tr '[:upper:]' '[:lower:]')" == "$lower" ]]; }; then pick=$p; fi
      done <<< "$players"
      [[ -n "$pick" ]] || audio_fail 3 "No media app called $want is open" ;;
  esac
  mkdir -p "$(dirname "$audio_player_file")"
  printf '%s\n' "$pick" > "$audio_player_file"
  name=$(audio_player_name "$pick")
  track=$(playerctl -p "$pick" metadata title 2>/dev/null || true)
  takumi notice play "Media keys: $name" "$track" >/dev/null 2>&1 || true
  echo "The media keys control $name"
}

# Sound quality: Balanced (one sample rate, a longer buffer: the least battery, never a crackle) or Studio
# (each song at its own rate, a short delay: for hi-res music, recording and instruments). The choice is a
# pipewire.conf.d file in the home, copied from default/pipewire/, and applied at once through PipeWire's
# settings metadata (each default.clock.<key> in the file is clock.<key> there), so nothing restarts.
audio_quality_now() {
  local q=""
  if [[ -f "$audio_quality_file" ]]; then q=$(sed -n '1s/^# takumi sound quality: //p' "$audio_quality_file"); fi
  case "$q" in studio) echo studio ;; *) echo balanced ;; esac
}
audio_quality_name() { if [[ $1 == studio ]]; then echo "Studio quality"; else echo Balanced; fi; }
audio_quality_set() {
  local src="$audio_default/pipewire/$1.conf" key val
  [[ -f "$src" ]] || audio_fail 1 "Takumi's sound settings are missing ($src)"
  mkdir -p "$(dirname "$audio_quality_file")"
  cp "$src" "$audio_quality_file.tmp" && mv "$audio_quality_file.tmp" "$audio_quality_file"
  while read -r key val; do
    if [[ -n "$key" ]]; then pw-metadata -n settings 0 "$key" "$val" >/dev/null 2>&1 || true; fi
  done <<< "$(sed -n 's/#.*//; s/^ *default\.\(clock\.[a-z-]*\) *= *\(.*[^ ]\) *$/\1 \2/p' "$src")"
}

# Speaker tunings: a filter graph (EQ and limiter) that PipeWire runs in front of the built-in speakers,
# as data in default/audio/tunings/<name>.conf (a person's own in ~/.config/takumi/tunings/ win). The
# computer's tuning, which its hardware data chooses, is a name in /var/lib/takumi/audio/tuning; a person's
# own choice in ~/.config/takumi/sound.toml wins over it.
audio_tuning_dirs() { printf '%s\n' "$HOME/.config/takumi/tunings" "$audio_default/audio/tunings"; }
# audio_tuning_file <name>: the tuning's file. Fails for a name that is not one.
audio_tuning_file() {
  local d
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]] || return 1
  while IFS= read -r d; do
    if [[ -f "$d/$1.conf" ]]; then printf '%s\n' "$d/$1.conf"; return 0; fi
  done <<< "$(audio_tuning_dirs)"
  return 1
}
# audio_tuning_meta <file> <title|about|needs>: a "# key: value" line from a tuning's head.
audio_tuning_meta() { awk -v k="# $2: " 'index($0, k) == 1 { print substr($0, length(k) + 1); exit }' "$1"; }
# Every tuning, one per line: name <tab> title.
audio_tuning_list() {
  local d f n seen=" "
  while IFS= read -r d; do
    for f in "$d"/*.conf; do
      [[ -f "$f" ]] || continue
      n=$(basename "$f" .conf)
      [[ "$n" =~ ^[a-z0-9][a-z0-9-]*$ && "$seen" != *" $n "* ]] || continue
      seen="$seen$n "
      printf '%s\t%s\n' "$n" "$(audio_tuning_meta "$f" title)"
    done
  done <<< "$(audio_tuning_dirs)"
}
# audio_setting <table> <key>: a value from sound.toml, or nothing.
audio_setting() {
  [[ -f "$audio_config" ]] || return 0
  awk -v t="[$1]" -v k="$2" '
    /^\[/ { inside = ($0 == t); next }
    inside && $1 == k && $2 == "=" { v = $0; sub(/^[^"]*"/, "", v); sub(/".*$/, "", v); print v; exit }' "$audio_config"
}
# audio_tuning_save <state on|off> <profile> <node> <route>: a person's choice, written whole. The node and its
# route are set only when a person tuned an output other than the built-in speakers.
audio_tuning_save() {
  mkdir -p "$(dirname "$audio_config")"
  {
    printf '# Sound, as set from the Core. See docs/sound.md.\n\n'
    printf '[tuning]\n'
    printf 'state = "%s"\n' "$1"
    printf 'profile = "%s"\n' "$2"
    printf 'node = "%s"\n' "$(printf '%s' "$3" | tr -d '"')"
    printf 'route = "%s"\n' "$(printf '%s' "$4" | tr -d '"')"
  } > "$audio_config.tmp"
  mv "$audio_config.tmp" "$audio_config"
}
# The tuning this computer's hardware calls for, or nothing.
audio_tuning_computer() {
  local p=""
  if [[ -r "$audio_machine/tuning" ]]; then IFS= read -r p < "$audio_machine/tuning" || true; fi
  if [[ "$p" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then printf '%s\n' "$p"; fi
}
# The tuning that should run for this person, or nothing: their own choice, else the computer's.
audio_tuning_wanted() {
  local state profile
  state=$(audio_setting tuning state); profile=$(audio_setting tuning profile)
  case "$state" in
    off) return 0 ;;
    on) [[ -n "$profile" ]] || profile=$(audio_tuning_computer); printf '%s\n' "${profile:-laptop-speakers}" ;;
    *) audio_tuning_computer ;;
  esac
}
# audio_tuning_missing <file>: when a LADSPA plugin the tuning runs is not installed, the package it needs
# (the tuning's "# needs:" line, else the plugin's name), and true. An LV2 plugin is named by an address
# and is left to PipeWire to find.
audio_tuning_missing() {
  local p d found need
  while IFS= read -r p; do
    [[ -n "$p" && "$p" != *:* ]] || continue
    found=no
    while IFS= read -r d; do
      if [[ -n "$d" ]] && { [[ -f "$d/$p.so" ]] || [[ -f "$d/$p" ]]; }; then found=yes; fi
    done <<< "$(printf '%s\n' "${LADSPA_PATH:-/usr/lib/ladspa:/usr/lib64/ladspa}" | tr ':' '\n')"
    if [[ $found == no ]]; then
      need=$(audio_tuning_meta "$1" needs)
      if [[ -n "$need" ]]; then printf '%s\n' "${need%% *}"; else printf '%s\n' "$p"; fi
      return 0
    fi
  done <<< "$(sed -n 's/#.*//; s/^.*plugin *= *"\{0,1\}\([^" ]*\)"\{0,1\}.*$/\1/p' "$1")"
  return 1
}
# The built-in speakers, from a dump on stdin: {id, name, route} of the output whose device has a speaker
# route, whichever route is in use now (headphones may be plugged in), or nothing.
audio_speakers() {
  jq -c "$audio_jq"'
    (map(select(.type == "PipeWire:Interface:Device")
         | {key: (.id | tostring), value: ((.info.params.EnumRoute // []) + (.info.params.Route // []))}) | from_entries) as $routes
    | first(.[] | select(.type == "PipeWire:Interface:Node" and ((prop("media.class") // "") | startswith("Audio/Sink"))
                         and ((prop("filter.smart") | truthy) | not))
            | (prop("card.profile.device") | tostring) as $pd
            | first(($routes[(prop("device.id") // "" | tostring)] // [])[]
                    | select(.direction == "Output" and (((.name // "") + " " + (.description // "")) | ascii_downcase | test("speaker"))
                             and ((.devices // [.device]) | map(tostring) | index($pd) != null))) as $r
            | {id: .id, name: prop("node.name"), route: $r.name}) // empty'
}
# audio_tuning_config <tuning file> <node name>: the PipeWire configuration the tuning runs as, a small
# PipeWire of its own (as PipeWire's filter-chain.conf runs filters) whose one filter is a WirePlumber smart
# filter in front of that node: whatever plays to the speakers goes through it, and it is never an output
# of its own. It starts disabled; takumi audio tuning run turns it on while the speakers' route is in use.
# https://docs.pipewire.org/page_module_filter_chain.html
# https://pipewire.pages.freedesktop.org/wireplumber/policies/smart_filters.html
audio_tuning_config() {
  printf '# Written by takumi audio tuning from %s, for %s, at each start. See docs/sound.md.\n' "$1" "$2"
  cat <<'HEAD'
context.properties = {
    log.level = 0
}
context.spa-libs = {
    audio.convert.* = audioconvert/libspa-audioconvert
    support.*       = support/libspa-support
}
context.modules = [
    { name = libpipewire-module-rt flags = [ ifexists nofail ] }
    { name = libpipewire-module-protocol-native }
    { name = libpipewire-module-client-node }
    { name = libpipewire-module-adapter }
    { name = libpipewire-module-filter-chain
        args = {
            node.description = "Speaker tuning"
            media.name       = "Speaker tuning"
HEAD
  sed 's/^/            /' "$1"
  cat <<TAIL
            audio.channels = 2
            audio.position = [ FL FR ]
            capture.props = {
                node.name             = "takumi_tuning"
                media.class           = Audio/Sink
                filter.smart          = true
                filter.smart.name     = "takumi-tuning"
                filter.smart.disabled = true
                filter.smart.target   = { node.name = "$2" }
            }
            playback.props = {
                node.name         = "takumi_tuning.out"
                node.passive      = true
                stream.dont-remix = true
            }
        }
    }
]
TAIL
}
# audio_tuning_follow <node name> <route> <tuning pid>: turn the tuning on while that node's route is in use
# (the speakers, not the headphones on the same jack) and off otherwise, as PipeWire reports each change:
# pw-dump -m prints the graph, then each change, as JSON. With no route, it stays on. Returns 1 when the
# tuning or PipeWire goes away. The filter's node id is kept in audio_tuning_fid for the clean-up.
audio_tuning_fid=""
audio_tuning_follow() {
  local node=$1 route=$2 pid=$3 line last="" seen=no rc engaged fid
  exec 3< <(pw-dump -m -N 2>/dev/null | jq -n --unbuffered -r --arg node "$node" --arg route "$route" '
    def keep($o):
      ($o.id | tostring) as $k
      | if $o.info == null then del(.nodes[$k]) | del(.routes[$k])
        elif $o.type == "PipeWire:Interface:Node" and $o.info.props != null then
          .nodes[$k] = {name: ($o.info.props["node.name"] // ""), device: ($o.info.props["device.id"] // "" | tostring),
                        pd: ($o.info.props["card.profile.device"] // "" | tostring), smart: ($o.info.props["filter.smart.name"] // "")}
        elif $o.type == "PipeWire:Interface:Device" and $o.info.params.Route != null then .routes[$k] = $o.info.params.Route
        else . end;
    foreach inputs as $batch ({nodes: {}, routes: {}}; reduce ($batch[]?) as $o (.; keep($o));
      ([.nodes[] | select(.name == $node)] | first) as $n
      | ([.nodes | to_entries[] | select(.value.smart == "takumi-tuning") | .key] | first // "0") as $f
      | (if $n == null then "no" elif $route == "" then "yes"
         elif ([(.routes[$n.device] // [])[] | select(.direction == "Output" and (.device | tostring) == $n.pd) | .name] | first) == $route then "yes"
         else "no" end) + " " + $f)')
  while :; do
    rc=0; IFS= read -r -t 2 line <&3 || rc=$?
    if (( rc > 128 )); then kill -0 "$pid" 2>/dev/null || return 1; continue; fi   # a quiet moment: is the tuning still there?
    (( rc == 0 )) || return 1                                                       # PipeWire went away
    engaged=${line%% *}; fid=${line##* }
    if [[ "$fid" == 0 ]]; then [[ $seen == no ]] || return 1; continue; fi        # its node went away
    seen=yes; audio_tuning_fid=$fid
    [[ "$line" != "$last" ]] || continue
    last=$line
    if [[ $engaged == yes ]]; then
      pw-metadata -n filters "$fid" filter.smart.disabled false Spa:String:JSON >/dev/null 2>&1 || true
    else
      pw-metadata -n filters "$fid" filter.smart.disabled true Spa:String:JSON >/dev/null 2>&1 || true
    fi
  done
}
# Start (or start again) the tuning for this session: Takumi's takumi-tuning.service when it is installed,
# else the same command as a unit of its own until the session ends.
audio_tuning_start() {
  local unit
  unit=$(systemctl --user cat takumi-tuning.service 2>/dev/null | sed -n 1p || true)
  systemctl --user stop takumi-tuning.service >/dev/null 2>&1 || true
  if [[ "$unit" == *"/systemd/user/takumi-tuning.service" ]]; then
    systemctl --user start takumi-tuning.service >/dev/null 2>&1
  else
    systemd-run --user --unit=takumi-tuning --collect --quiet takumi audio tuning run >/dev/null 2>&1
  fi
}
audio_tuning_stop() { systemctl --user stop takumi-tuning.service >/dev/null 2>&1 || true; }
# True while the tuning's filter is in the graph (a dump on stdin).
audio_tuning_running() { [[ "$(jq -r 'any(.[]; (.info.props // {})["node.name"] == "takumi_tuning")')" == true ]]; }
